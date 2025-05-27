#!/bin/bash

# backup.sh - 마인크래프트 월드 백업 스크립트 (개선 버전)
# 12시간마다 실행되어 월드 데이터를 백업하고 최근 2개만 보관

set -e  # 오류 발생시 스크립트 중단

# 설정
MINECRAFT_HOME="/home/minecraft"
WORLD_DIR="$MINECRAFT_HOME/world"
BACKUP_DIR="$MINECRAFT_HOME/backups"
DEPLOY_LOG_DIR="$MINECRAFT_HOME/deploy-logs"
LOG_FILE="$DEPLOY_LOG_DIR/backup-$(date +%Y%m%d).log"

# 백업 파일명 (타임스탬프 포함)
BACKUP_FILENAME="world-backup-$(date +%Y%m%d_%H%M).tar.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILENAME"

# 보관할 백업 개수
KEEP_BACKUPS=2

# 로그 함수
log() {
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] $1" | tee -a "$LOG_FILE"
}

log "=== 월드 백업 시작 ==="

# 백업 디렉토리 생성
mkdir -p "$BACKUP_DIR"
mkdir -p "$DEPLOY_LOG_DIR"

# 월드 디렉토리 존재 확인
if [ ! -d "$WORLD_DIR" ]; then
   log "ERROR: 월드 디렉토리가 존재하지 않습니다: $WORLD_DIR"
   exit 1
fi

# 월드 디렉토리 크기 확인
world_size=$(du -sh "$WORLD_DIR" | cut -f1)
log "백업 대상 월드 크기: $world_size"

# 디스크 공간 확인
log "디스크 공간 확인 중..."
available_space=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
world_size_kb=$(du -sk "$WORLD_DIR" | cut -f1)
required_space=$((world_size_kb * 2))  # 압축을 고려한 여유 공간

if [ "$available_space" -lt "$required_space" ]; then
    log "ERROR: 디스크 공간이 부족합니다. (필요: ${required_space}KB, 사용가능: ${available_space}KB)"
    exit 1
fi

log "디스크 공간 충분 (사용가능: $(($available_space/1024))MB)"

# 백업 생성
log "백업 파일 생성 중: $BACKUP_FILENAME"
start_time=$(date +%s)

# tar를 사용하여 압축 백업 생성
if tar -czf "$BACKUP_PATH" -C "$MINECRAFT_HOME" "world/"; then
   # 백업 파일 권한을 소유자만 읽기/쓰기로 제한
   chmod 600 "$BACKUP_PATH"
   
   end_time=$(date +%s)
   duration=$((end_time - start_time))
   backup_size=$(du -sh "$BACKUP_PATH" | cut -f1)
   
   log "백업 생성 완료 (소요시간: ${duration}초, 크기: $backup_size)"
else
   log "ERROR: 백업 생성 실패"
   exit 1
fi

# 백업 파일 검증
if [ -f "$BACKUP_PATH" ] && [ -s "$BACKUP_PATH" ]; then
   log "백업 파일 검증 성공: $BACKUP_PATH"
else
   log "ERROR: 백업 파일 검증 실패"
   exit 1
fi

# 기존 백업 정리 (최근 N개만 보관)
log "기존 백업 파일 정리 중..."

# 백업 파일이 존재하는지 먼저 확인
if ls "$BACKUP_DIR"/world-backup-*.tar.gz 1> /dev/null 2>&1; then
    backup_files=$(ls -t "$BACKUP_DIR"/world-backup-*.tar.gz)
    backup_count=$(echo "$backup_files" | wc -l)
    
    log "현재 백업 파일 개수: $backup_count"
    
    if [ "$backup_count" -gt "$KEEP_BACKUPS" ]; then
        # 보관할 개수를 초과하는 오래된 백업 삭제
        files_to_delete=$(echo "$backup_files" | tail -n +$((KEEP_BACKUPS + 1)))
        
        for file in $files_to_delete; do
            if [ -f "$file" ]; then
                file_size=$(du -sh "$file" | cut -f1)
                rm -f "$file"
                log "오래된 백업 삭제: $(basename "$file") (크기: $file_size)"
            fi
        done
        
        remaining_count=$(ls -1 "$BACKUP_DIR"/world-backup-*.tar.gz 2>/dev/null | wc -l)
        log "백업 정리 완료 (남은 백업: $remaining_count개)"
    else
        log "백업 정리 불필요 (현재: $backup_count개, 최대: $KEEP_BACKUPS개)"
    fi
else
    log "기존 백업 파일이 없습니다."
fi

# 최종 백업 현황 출력
log "=== 현재 백업 현황 ==="
if ls "$BACKUP_DIR"/world-backup-*.tar.gz 1> /dev/null 2>&1; then
   for backup in $(ls -t "$BACKUP_DIR"/world-backup-*.tar.gz); do
       backup_name=$(basename "$backup")
       backup_size=$(du -sh "$backup" | cut -f1)
       backup_date=$(echo "$backup_name" | sed 's/world-backup-\(.*\)\.tar\.gz/\1/' | sed 's/_/ /')
       log "  - $backup_name (크기: $backup_size, 날짜: $backup_date)"
   done
else
   log "  백업 파일이 없습니다."
fi

# 디스크 사용량 확인
backup_dir_size=$(du -sh "$BACKUP_DIR" | cut -f1)
log "백업 디렉토리 총 크기: $backup_dir_size"

# 최종 상태 요약
total_backups=$(ls -1 "$BACKUP_DIR"/world-backup-*.tar.gz 2>/dev/null | wc -l)
log "백업 완료 - 총 ${total_backups}개 백업 보관 중"

log "=== 월드 백업 완료 ==="
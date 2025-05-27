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

log "=== World Backup Started ==="

# 백업 디렉토리 생성
mkdir -p "$BACKUP_DIR"
mkdir -p "$DEPLOY_LOG_DIR"

# 월드 디렉토리 존재 확인
if [ ! -d "$WORLD_DIR" ]; then
   log "ERROR: World directory does not exist: $WORLD_DIR"
   exit 1
fi

# 월드 디렉토리 크기 확인
world_size=$(du -sh "$WORLD_DIR" | cut -f1)
log "Target world size: $world_size"

# 디스크 공간 확인
log "Checking disk space..."
available_space=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
world_size_kb=$(du -sk "$WORLD_DIR" | cut -f1)
required_space=$((world_size_kb * 2))  # 압축을 고려한 여유 공간

if [ "$available_space" -lt "$required_space" ]; then
    log "ERROR: Insufficient disk space. (Required: ${required_space}KB, Available: ${available_space}KB)"
    exit 1
fi

log "Sufficient disk space (Available: $(($available_space/1024))MB)"

# 백업 생성
log "Creating backup file: $BACKUP_FILENAME"
start_time=$(date +%s)

# tar를 사용하여 압축 백업 생성
if tar -czf "$BACKUP_PATH" -C "$MINECRAFT_HOME" "world/"; then
   # 백업 파일 권한을 소유자만 읽기/쓰기로 제한
   chmod 600 "$BACKUP_PATH"
   
   end_time=$(date +%s)
   duration=$((end_time - start_time))
   backup_size=$(du -sh "$BACKUP_PATH" | cut -f1)
   
   log "Backup creation completed (Duration: ${duration}s, Size: $backup_size)"
else
   log "ERROR: Backup creation failed"
   exit 1
fi

# 백업 파일 검증
if [ -f "$BACKUP_PATH" ] && [ -s "$BACKUP_PATH" ]; then
   log "Backup file verification successful: $BACKUP_PATH"
else
   log "ERROR: Backup file verification failed"
   exit 1
fi

# 기존 백업 정리 (최근 N개만 보관)
log "Cleaning up old backup files..."

# 백업 파일이 존재하는지 먼저 확인
if ls "$BACKUP_DIR"/world-backup-*.tar.gz 1> /dev/null 2>&1; then
    backup_files=$(ls -t "$BACKUP_DIR"/world-backup-*.tar.gz)
    backup_count=$(echo "$backup_files" | wc -l)
    
    log "Current backup file count: $backup_count"
    
    if [ "$backup_count" -gt "$KEEP_BACKUPS" ]; then
        # 보관할 개수를 초과하는 오래된 백업 삭제
        files_to_delete=$(echo "$backup_files" | tail -n +$((KEEP_BACKUPS + 1)))
        
        for file in $files_to_delete; do
            if [ -f "$file" ]; then
                file_size=$(du -sh "$file" | cut -f1)
                rm -f "$file"
                log "Deleted old backup: $(basename "$file") (Size: $file_size)"
            fi
        done
        
        remaining_count=$(ls -1 "$BACKUP_DIR"/world-backup-*.tar.gz 2>/dev/null | wc -l)
        log "Cleanup completed (Remaining backups: $remaining_count)"
    else
        log "No cleanup needed (Current: $backup_count, Max: $KEEP_BACKUPS)"
    fi
else
    log "No existing backup files found"
fi

# 최종 백업 현황 출력
log "=== Current Backup Status ==="
if ls "$BACKUP_DIR"/world-backup-*.tar.gz 1> /dev/null 2>&1; then
   for backup in $(ls -t "$BACKUP_DIR"/world-backup-*.tar.gz); do
       backup_name=$(basename "$backup")
       backup_size=$(du -sh "$backup" | cut -f1)
       backup_date=$(echo "$backup_name" | sed 's/world-backup-\(.*\)\.tar\.gz/\1/' | sed 's/_/ /')
       log "  - $backup_name (Size: $backup_size, Date: $backup_date)"
   done
else
   log "  No backup files exist"
fi

# 디스크 사용량 확인
backup_dir_size=$(du -sh "$BACKUP_DIR" | cut -f1)
log "Total backup directory size: $backup_dir_size"

# 최종 상태 요약
total_backups=$(ls -1 "$BACKUP_DIR"/world-backup-*.tar.gz 2>/dev/null | wc -l)
log "Backup completed - Maintaining $total_backups backup(s)"

log "=== World Backup Completed ==="
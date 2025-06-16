#!/bin/bash

# file-sync.sh - 파일 동기화 스크립트
# 레포의 파일들을 서버 디렉토리로 동기화

set -e  # 오류 발생시 스크립트 중단

# 설정
MINECRAFT_HOME="/home/minecraft"
REPO_DIR="$(pwd)"
DEPLOY_LOG_DIR="$MINECRAFT_HOME/deploy-logs"
LOG_FILE="$DEPLOY_LOG_DIR/deploy-$(date +%Y%m%d).log"

# 로그 함수
log() {
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FILE-SYNC] $1" | tee -a "$LOG_FILE"
}

# 사용법 체크
if [ $# -eq 0 ]; then
   echo "사용법: $0 <sync_target>"
   echo "가능한 target: docker, scripts, all"
   exit 1
fi

SYNC_TARGET="$1"

# 디렉토리 존재 확인
if [ ! -d "$MINECRAFT_HOME" ]; then
   log "ERROR: 마인크래프트 홈 디렉토리가 존재하지 않습니다: $MINECRAFT_HOME"
   exit 1
fi

# 파일 동기화 함수 (디렉토리용)
sync_files() {
   local source_dir="$1"
   local target_dir="$2"
   local description="$3"
   
   if [ ! -d "$REPO_DIR/$source_dir" ]; then
       log "WARNING: 소스 디렉토리가 존재하지 않습니다: $REPO_DIR/$source_dir"
       return 1
   fi
   
   log "$description 동기화 시작: $source_dir -> $target_dir"
   
   # 타겟 디렉토리 생성
   mkdir -p "$target_dir"
   
   # rsync로 디렉토리 동기화
   rsync -av --delete "$REPO_DIR/$source_dir/" "$target_dir/"
   log "디렉토리 동기화 완료"
}

# 개별 파일 동기화 함수
sync_single_file() {
   local source_file="$1"
   local target_file="$2"
   local description="$3"
   
   if [ ! -f "$REPO_DIR/$source_file" ]; then
       log "WARNING: 소스 파일이 존재하지 않습니다: $REPO_DIR/$source_file"
       return 1
   fi
   
   log "$description 파일 동기화: $source_file -> $target_file"
   
   # 타겟 디렉토리 생성
   mkdir -p "$(dirname "$target_file")"
   
   # rsync로 개별 파일 동기화
   rsync -av "$REPO_DIR/$source_file" "$target_file"
   log "파일 동기화 완료: $target_file"
}

log "=== 파일 동기화 시작: $SYNC_TARGET ==="

# 동기화 대상에 따른 처리
case "$SYNC_TARGET" in
   "docker")
       log "Docker 설정 동기화 중..."
       sync_single_file "docker/docker-compose.yml" "$MINECRAFT_HOME/docker-compose.yml" "Docker Compose"
       ;;
       
   "scripts")
       log "스크립트 파일 동기화 중..."
       sync_files "scripts" "$MINECRAFT_HOME/scripts" "스크립트"
       # 실행 권한 부여
       chmod 750 "$MINECRAFT_HOME/scripts/"*.sh 2>/dev/null || true
       log "스크립트 실행 권한 부여 완료"
       ;;
       
   "all")
       log "모든 파일 동기화 중..."
       sync_single_file "docker/docker-compose.yml" "$MINECRAFT_HOME/docker-compose.yml" "Docker Compose"
       sync_files "scripts" "$MINECRAFT_HOME/scripts" "스크립트"
       chmod 750 "$MINECRAFT_HOME/scripts/"*.sh 2>/dev/null || true
       log "모든 파일 동기화 및 권한 설정 완료"
       ;;
       
   *)
       log "ERROR: 알 수 없는 동기화 대상: $SYNC_TARGET"
       echo "가능한 옵션: docker, scripts, all"
       exit 1
       ;;
esac

log "=== 파일 동기화 완료: $SYNC_TARGET ==="
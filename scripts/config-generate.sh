#!/bin/bash

# config-generate.sh - 서버 설정 파일 생성 스크립트
# .env.minecraft와 server.properties.template을 결합하여 server.properties 생성

set -e  # 오류 발생시 스크립트 중단

# 설정
MINECRAFT_HOME="/home/minecraft"
REPO_DIR="$(pwd)"
DEPLOY_LOG_DIR="$MINECRAFT_HOME/deploy-logs"
LOG_FILE="$DEPLOY_LOG_DIR/deploy-$(date +%Y%m%d).log"

# 파일 경로
TEMPLATE_FILE="$REPO_DIR/config/server.properties.template"
ENV_FILE="$MINECRAFT_HOME/.env.minecraft"
OUTPUT_FILE="$MINECRAFT_HOME/server.properties"

# 로그 함수
log() {
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CONFIG-GEN] $1" | tee -a "$LOG_FILE"
}

log "=== 서버 설정 파일 생성 시작 ==="

# 템플릿 파일 존재 확인
if [ ! -f "$TEMPLATE_FILE" ]; then
   log "ERROR: 템플릿 파일이 존재하지 않습니다: $TEMPLATE_FILE"
   exit 1
fi

# 환경변수 파일 존재 확인
if [ ! -f "$ENV_FILE" ]; then
   log "ERROR: 환경변수 파일이 존재하지 않습니다: $ENV_FILE"
   exit 1
fi

log "템플릿 파일: $TEMPLATE_FILE"
log "환경변수 파일: $ENV_FILE"
log "출력 파일: $OUTPUT_FILE"

# 환경변수 파일 로드
log "환경변수 파일 로드 중..."
set -a  # 모든 변수를 자동으로 export
source "$ENV_FILE"
set +a

# 템플릿에서 환경변수를 치환하여 server.properties 생성
log "템플릿 파일 처리 중..."
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# 생성 결과 확인
if [ -f "$OUTPUT_FILE" ]; then
   file_size=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || wc -c < "$OUTPUT_FILE")
   log "server.properties 생성 완료 (크기: ${file_size}바이트)"
   
   # 생성된 파일의 권한 설정
   chmod 644 "$OUTPUT_FILE"
   log "파일 권한 설정 완료 (644)"
   
   # 주요 설정값 로그 출력 (디버깅용)
   if grep -q "server-port=" "$OUTPUT_FILE"; then
       server_port=$(grep "server-port=" "$OUTPUT_FILE" | cut -d'=' -f2)
       log "설정된 서버 포트: $server_port"
   fi
   
   if grep -q "max-players=" "$OUTPUT_FILE"; then
       max_players=$(grep "max-players=" "$OUTPUT_FILE" | cut -d'=' -f2)
       log "최대 플레이어 수: $max_players"
   fi
   
else
   log "ERROR: server.properties 파일 생성 실패"
   exit 1
fi

log "=== 서버 설정 파일 생성 완료 ==="
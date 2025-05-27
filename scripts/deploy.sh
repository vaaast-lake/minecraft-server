#!/bin/bash

# deploy.sh - 메인 배포 스크립트 (개선된 버전)
# 워크플로우에서 전달받은 배포 전략에 따라 실행

set -e  # 오류 발생시 스크립트 중단

# 설정
MINECRAFT_HOME="/home/minecraft"
REPO_DIR="$(pwd)"
LOG_FILE="$MINECRAFT_HOME/deploy-logs/deploy-$(date +%Y%m%d).log"

# 로그 함수
log() {
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 도움말 함수
show_help() {
   cat << EOF
마인크래프트 서버 배포 스크립트

사용법: $0 [옵션]

배포 전략:
  --strategy=docker-recreate       Docker 컨테이너 재생성 (전체 재배포)
  --strategy=scripts-only          스크립트 파일만 동기화 (재시작 없음)

옵션:
  --force                       강제 실행 (변경사항 무시)
  --help, -h                    도움말 표시

예시:
  $0 --strategy=docker-recreate --force
EOF
   exit 0
}

# 인자 파싱
DEPLOY_STRATEGY=""
FORCE_DEPLOY="${FORCE_DEPLOY:-false}"

while [[ $# -gt 0 ]]; do
   case $1 in
       --strategy=*)
           DEPLOY_STRATEGY="${1#*=}"
           shift
           ;;
       --force)
           FORCE_DEPLOY="true"
           shift
           ;;
       --help|-h)
           show_help
           ;;
       *)
           echo "알 수 없는 옵션: $1"
           echo "도움말을 보려면 --help를 사용하세요."
           exit 1
           ;;
   esac
done

# 필수 인자 확인
if [ -z "$DEPLOY_STRATEGY" ]; then
   echo "배포 전략이 지정되지 않았습니다."
   echo "사용법: $0 --strategy=<전략>"
   exit 1
fi

log "=== 배포 시작: 전략=$DEPLOY_STRATEGY, 강제실행=$FORCE_DEPLOY ==="

# 배포 전략별 실행
case "$DEPLOY_STRATEGY" in
   "docker-recreate")
       log "Docker 재생성 배포 실행 중..."
       
       # Docker 설정 동기화
       log "Docker 설정 동기화 중..."
       ./scripts/file-sync.sh docker
       
       # 스크립트 동기화
       log "스크립트 파일 동기화 중..."
       ./scripts/file-sync.sh scripts
       
       # 컨테이너 재생성
       log "Docker 컨테이너 재생성 중..."
       docker compose up -d --force-recreate
       ;;
       
   "scripts-only")
       log "스크립트 파일만 동기화 실행 중..."
       
       # 스크립트 파일만 동기화
       ./scripts/file-sync.sh scripts
       
       log "스크립트 동기화 완료 - 서버 재시작 불필요"
       ;;
       
   *)
       log "ERROR: 알 수 없는 배포 전략: $DEPLOY_STRATEGY"
       exit 1
       ;;
esac

log "=== 배포 완료: $DEPLOY_STRATEGY ==="
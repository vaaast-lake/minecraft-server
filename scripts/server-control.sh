#!/bin/bash

# server-control.sh - 마인크래프트 서버 제어 스크립트
# 서버 시작, 중지, 재시작, 상태 확인 기능 제공
# Docker Compose v2 호환 버전

set -e  # 오류 발생시 스크립트 중단

# 설정
MINECRAFT_HOME="/home/minecraft"
DOCKER_COMPOSE_FILE="$MINECRAFT_HOME/docker-compose.yml"
DEPLOY_LOG_DIR="$MINECRAFT_HOME/deploy-logs"
LOG_FILE="$DEPLOY_LOG_DIR/server-control-$(date +%Y%m%d).log"

# 컨테이너명 (docker-compose.yml에 정의된 서비스명)
SERVICE_NAME="mc"

# 로그 함수
log() {
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SERVER-CTRL] $1" | tee -a "$LOG_FILE"
}

# 도움말 출력 (정상 종료)
show_help() {
   cat << EOF
마인크래프트 서버 제어 스크립트

사용법: $0 <command>

가능한 명령어:
  start    - 서버 시작
  stop     - 서버 중지  
  restart  - 서버 재시작
  status   - 서버 상태 확인
  logs     - 서버 로그 출력 (실시간)
  help     - 이 도움말 표시

옵션:
  -h, --help    이 도움말 표시

예시:
  $0 start      # 서버 시작
  $0 status     # 서버 상태 확인
  $0 logs       # 서버 로그 보기
EOF
   exit 0
}

# 에러 시 사용법 출력 (에러 종료)
usage_error() {
   if [ -n "$1" ]; then
       echo "오류: $1" >&2
   fi
   echo "" >&2
   echo "사용법: $0 <command>" >&2
   echo "사용 가능한 명령어: start, stop, restart, status, logs, help" >&2
   echo "자세한 도움말: $0 --help" >&2
   exit 1
}

# Docker Compose 파일 존재 확인
check_docker_compose() {
   if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
       log "ERROR: Docker Compose 파일이 존재하지 않습니다: $DOCKER_COMPOSE_FILE"
       exit 1
   fi
}

# 서버 상태 확인
get_server_status() {
   if docker compose -f "$DOCKER_COMPOSE_FILE" ps -q "$SERVICE_NAME" > /dev/null 2>&1; then
       local container_id=$(docker compose -f "$DOCKER_COMPOSE_FILE" ps -q "$SERVICE_NAME")
       if [ -n "$container_id" ]; then
           local status=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null || echo "unknown")
           echo "$status"
       else
           echo "not_created"
       fi
   else
       echo "not_created"
   fi
}

# 서버 시작
start_server() {
   log "=== 서버 시작 ==="
   
   local status=$(get_server_status)
   
   if [ "$status" = "running" ]; then
       log "서버가 이미 실행 중입니다."
       return 0
   fi
   
   log "서버 시작 중..."
   
   if docker compose -f "$DOCKER_COMPOSE_FILE" up -d "$SERVICE_NAME"; then
       log "서버 시작 명령 실행 완료"
       
       # 서버 시작 대기 (최대 60초)
       local wait_count=0
       while [ $wait_count -lt 60 ]; do
           local current_status=$(get_server_status)
           if [ "$current_status" = "running" ]; then
               log "서버 시작 성공 (대기시간: ${wait_count}초)"
               return 0
           fi
           sleep 1
           wait_count=$((wait_count + 1))
       done
       
       log "WARNING: 서버 시작 확인 시간 초과"
   else
       log "ERROR: 서버 시작 실패"
       exit 1
   fi
}

# 서버 중지
stop_server() {
   log "=== 서버 중지 ==="
   
   local status=$(get_server_status)
   
   if [ "$status" != "running" ]; then
       log "서버가 실행 중이 아닙니다. (상태: $status)"
       return 0
   fi
   
   log "서버 중지 중..."
   
   # Graceful shutdown 시도
   if docker compose -f "$DOCKER_COMPOSE_FILE" stop "$SERVICE_NAME"; then
       log "서버 중지 명령 실행 완료"
       
       # 서버 중지 대기 (최대 30초)
       local wait_count=0
       while [ $wait_count -lt 30 ]; do
           local current_status=$(get_server_status)
           if [ "$current_status" != "running" ]; then
               log "서버 중지 성공 (대기시간: ${wait_count}초)"
               return 0
           fi
           sleep 1
           wait_count=$((wait_count + 1))
       done
       
       log "WARNING: 정상 종료 시간 초과, 강제 종료 시도"
       docker compose -f "$DOCKER_COMPOSE_FILE" kill "$SERVICE_NAME"
       log "서버 강제 종료 완료"
   else
       log "ERROR: 서버 중지 실패"
       exit 1
   fi
}

# 서버 재시작
restart_server() {
   log "=== 서버 재시작 ==="
   stop_server
   sleep 2
   start_server
}

# 서버 상태 확인
show_status() {
   log "=== 서버 상태 확인 ==="
   
   local status=$(get_server_status)
   
   case "$status" in
       "running")
           log "서버 상태: 실행 중"
           
           # 컨테이너 정보 출력
           local container_id=$(docker compose -f "$DOCKER_COMPOSE_FILE" ps -q "$SERVICE_NAME")
           if [ -n "$container_id" ]; then
               local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$container_id" 2>/dev/null || echo "unknown")
               local memory=$(docker stats --no-stream --format "table {{.MemUsage}}" "$container_id" 2>/dev/null | tail -n 1 || echo "unknown")
               log "시작 시간: $uptime"
               log "메모리 사용량: $memory"
           fi
           ;;
       "exited")
           log "서버 상태: 중지됨"
           ;;
       "not_created")
           log "서버 상태: 생성되지 않음"
           ;;
       *)
           log "서버 상태: $status"
           ;;
   esac
   
   # Docker Compose 서비스 상태
   log "Docker Compose 서비스 상태:"
   docker compose -f "$DOCKER_COMPOSE_FILE" ps "$SERVICE_NAME" || true
}

# 서버 로그 출력
show_logs() {
   log "=== 서버 로그 출력 ==="
   
   local status=$(get_server_status)
   
   if [ "$status" = "not_created" ]; then
       log "서버 컨테이너가 생성되지 않았습니다."
       return 1
   fi
   
   # 최근 50줄의 로그 출력 후 실시간 따라가기
   docker compose -f "$DOCKER_COMPOSE_FILE" logs --tail=50 -f "$SERVICE_NAME"
}

# 명령어 처리 - 도움말 및 유효성 검사
if [ $# -eq 0 ]; then
   usage_error "명령어가 필요합니다"
fi

COMMAND="$1"

# 도움말 요청 및 명령어 처리를 한 번에
case "$COMMAND" in
   "-h"|"--help"|"help")
       show_help
       ;;
   "start"|"stop"|"restart"|"status"|"logs")
       # 유효한 명령어 - 아래에서 처리
       ;;
   *)
       usage_error "알 수 없는 명령어: '$COMMAND'"
       ;;
esac

# 로그 디렉토리 생성
mkdir -p "$DEPLOY_LOG_DIR"

# Docker Compose 파일 확인
check_docker_compose

# 명령어 실행
case "$COMMAND" in
   "start")
       start_server
       ;;
   "stop")
       stop_server
       ;;
   "restart")
       restart_server
       ;;
   "status")
       show_status
       ;;
   "logs")
       show_logs
       ;;
esac
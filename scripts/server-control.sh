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

사용법: $0 <command> [options]

가능한 명령어:
  start    - 서버 시작
  stop     - 서버 중지  
  restart  - 서버 재시작
  status   - 서버 상태 확인
  logs     - 서버 로그 출력 (실시간)
  help     - 이 도움말 표시

옵션:
  --recreate    재시작 시 컨테이너 완전 재생성 (down → up)
                기본값은 stop → start
  --graceful    중지/재시작 시 플레이어에게 사전 공지
                플레이어가 없으면 즉시 실행
  -h, --help    이 도움말 표시

예시:
  $0 start                          # 서버 시작
  $0 stop                           # 즉시 서버 중지
  $0 stop --graceful                # 플레이어 공지 후 서버 중지
  $0 restart                        # 일반 재시작 (stop → start)
  $0 restart --graceful             # 공지 후 일반 재시작
  $0 restart --recreate             # 컨테이너 재생성 (설정 변경 반영)
  $0 restart --recreate --graceful  # 공지 후 컨테이너 재생성
  $0 status                         # 서버 상태 확인
  $0 logs                           # 서버 로그 보기

참고:
  - --graceful 옵션은 stop, restart 명령어에서만 사용 가능
  - 플레이어가 접속 중일 때만 공지하며, 없으면 즉시 실행
  - 공지 순서: 2분전 → 1분전 → 30초전 → 10초 카운트다운 → 월드저장 → 실행
EOF
   exit 0
}

# 에러 시 사용법 출력 (에러 종료)
usage_error() {
   if [ -n "$1" ]; then
       echo "오류: $1" >&2
   fi
   echo "" >&2
   echo "사용법: $0 <command> [options]" >&2
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

# RCON 명령어 실행 함수
execute_rcon() {
   local command="$1"
   if ! docker compose -f "$DOCKER_COMPOSE_FILE" exec "$SERVICE_NAME" rcon-cli "$command" >/dev/null 2>&1; then
       log "WARNING: RCON 명령어 실행 실패: $command"
       return 1
   fi
   return 0
}

# 플레이어 수 확인 함수
get_player_count() {
   local player_output
   if player_output=$(docker compose -f "$DOCKER_COMPOSE_FILE" exec "$SERVICE_NAME" rcon-cli list 2>/dev/null); then
       local player_count=$(echo "$player_output" | grep -o "There are [0-9]\+" | grep -o "[0-9]\+" || echo "0")
       echo "$player_count"
   else
       log "WARNING: 플레이어 수 확인 실패"
       echo "0"
   fi
}

# Graceful 공지 및 대기 함수
graceful_announcement() {
   log "=== Graceful 서버 종료 시작 ==="
   
   local player_count=$(get_player_count)
   log "현재 플레이어 수: $player_count"
   
   # 플레이어가 없으면 공지 없이 바로 종료
   if [ "$player_count" -eq 0 ]; then
       log "플레이어가 없어 즉시 서버를 중지합니다."
       return 0
   fi
   
   # 플레이어가 있으면 graceful 공지 시작
   log "플레이어가 접속 중이므로 공지 후 서버를 중지합니다."
   
   # 2분 전 공지
   execute_rcon "say §b[공지] 2분 후 서버를 재시작할 예정입니다! 모두 안전한 곳으로 이동 후 종료해주시길 바랍니다!"
   log "2분 전 공지 완료"
   sleep 60
   
   # 1분 전 공지
   execute_rcon "say §c[공지] 서버가 1분 후 재시작됩니다!"
   log "1분 전 공지 완료"
   sleep 30
   
   # 30초 전 공지
   execute_rcon "say §c[공지] 서버가 30초 후 재시작됩니다!"
   log "30초 전 공지 완료"
   sleep 20
   
   # 10초 전 공지
   execute_rcon "say §c[공지] 서버가 10초 후 재시작됩니다!"
   log "10초 전 공지 완료"
   sleep 1
   
   # 카운트다운
   for i in {9..1}; do
       execute_rcon "say §c[공지] ${i}초..."
       sleep 1
   done
   
   # 월드 저장 공지 및 실행
   execute_rcon "say §4[공지] 월드를 저장합니다!"
   execute_rcon "save-all"
   log "월드 저장 완료"
   
   for i in {5..1}; do
       execute_rcon "say §c[공지] 월드 저장중..."
       sleep 1
   done
   
   # 최종 공지
   execute_rcon "say §4[공지] 서버를 재시작합니다!"
   log "Graceful 공지 완료"
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

    local graceful_mode=false
   
    # 플래그 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            --graceful)
                graceful_mode=true
                shift
                ;;
            *)
                usage_error "stop 명령어에 알 수 없는 옵션: '$1'"
                ;;
        esac
    done

   log "=== 서버 중지 ==="
   
   local status=$(get_server_status)
   
   if [ "$status" != "running" ]; then
       log "서버가 실행 중이 아닙니다. (상태: $status)"
       return 0
   fi

    # Graceful 모드면 공지 실행
    if [ "$graceful_mode" = true ]; then
        graceful_announcement
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

# 서버 완전 중지 (컨테이너 삭제)
down_server() {
    local graceful_mode=false
   
   # 플래그 파싱
   while [[ $# -gt 0 ]]; do
       case $1 in
           --graceful)
               graceful_mode=true
               shift
               ;;
           *)
               usage_error "down 명령어에 알 수 없는 옵션: '$1'"
               ;;
       esac
   done

   log "=== 서버 완전 중지 (컨테이너 삭제) ==="
   
   local status=$(get_server_status)
   
   if [ "$status" = "not_created" ]; then
       log "서버 컨테이너가 존재하지 않습니다."
       return 0
   fi

    # 서버가 실행 중이고 graceful 모드면 공지 실행
   if [ "$status" = "running" ] && [ "$graceful_mode" = true ]; then
       graceful_announcement
   fi
   
   log "서버 컨테이너 삭제 중..."
   
   if docker compose -f "$DOCKER_COMPOSE_FILE" down "$SERVICE_NAME"; then
       log "서버 컨테이너 삭제 완료"
   else
       log "ERROR: 서버 컨테이너 삭제 실패"
       exit 1
   fi
}

# 서버 재시작
restart_server() {
    local recreate_mode=false
    local graceful_mode=false

    # 플래그 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            --recreate)
                recreate_mode=true
                shift
                ;;
            --graceful)
                graceful_mode=true
                shift
                ;;
            *)
                usage_error "restart 명령어에 알 수 없는 옵션: '$1'"
                ;;
        esac
    done

    if [ "$recreate_mode" = true ]; then
       log "=== 서버 재시작 (컨테이너 재생성) ==="
       if [ "$graceful_mode" = true ]; then
            down_server --graceful
        else
            down_server
        fi
        sleep 2
        start_server
   else
       if [ "$graceful_mode" = true ]; then
            stop_server --graceful
        else
            stop_server
        fi
        sleep 2
        start_server
   fi
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

# 인자 파싱
COMMAND=""
COMMAND_OPTIONS=()

# 명령어 처리 - 도움말 및 유효성 검사
if [ $# -eq 0 ]; then
   usage_error "명령어가 필요합니다"
fi

COMMAND="$1"
shift

# 도움말 처리
case "$COMMAND" in
   "-h"|"--help"|"help")
       show_help
       ;;
esac

# 나머지 인자들을 명령어 옵션으로 저장 (옵션을 받는 명령어가 아닌 경우 에러 처리)
case "$COMMAND" in
   "restart"|"stop")
       COMMAND_OPTIONS=("$@")
       ;;
   "start"|"status"|"logs")
       if [ $# -gt 0 ]; then
           usage_error "'$COMMAND' 명령어는 추가 옵션을 받지 않습니다"
       fi
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
       stop_server "${COMMAND_OPTIONS[@]}"
       ;;
   "restart")
       restart_server "${COMMAND_OPTIONS[@]}"
       ;;
   "status")
       show_status
       ;;
   "logs")
       show_logs
       ;;
esac
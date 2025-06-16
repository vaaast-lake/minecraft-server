#!/bin/bash

cd /home/minecraft

check_players() {
  player_cnt=$(docker compose exec mc rcon-cli list | grep -o "There are [0-9]\+" | grep -o "[0-9]\+")
  echo $player_cnt
}

players=$(check_players)

if [ "$players" -gt 0 ]; then
    docker compose exec mc rcon-cli say "§b[공지] 2분 후 서버를 재시작할 예정입니다! 모두 안전한 곳으로 이동 후 종료해주시길 바랍니다!"
    sleep 60
fi

docker compose exec mc rcon-cli say "§c[공지] 서버가 1분 후 재시작됩니다!"
sleep 30

docker compose exec mc rcon-cli say "§c[공지] 서버가 30초 후 재시작됩니다!"
sleep 20

docker compose exec mc rcon-cli say "§c[공지] 서버가 10초 후 재시작됩니다!"
sleep 1
for i in {9..1}; do
  docker compose exec mc rcon-cli say "§c[공지] ${i}초..."
  sleep 1
done

docker compose exec mc rcon-cli say "§4[공지] 월드를 저장합니다!"
docker compose exec mc rcon-cli save-all
for i in {5..1}; do
  docker compose exec mc rcon-cli say "§c[공지] 월드 저장중..."
  sleep 1
done

docker compose exec mc rcon-cli say "§4[공지] 서버를 재시작합니다!"
docker compose restart mc

# 로그 기록
echo "$(date): 서버 재시작 완료 (이전 플레이어 수: $players)" >> /home/minecraft/restart.log

# 로그 파일 크기 관리 (1000줄 넘으면 최근 500줄만 유지)
if [ $(wc -l < /home/minecraft/restart.log 2>/dev/null || echo 0) -gt 1000 ]; then
    tail -n 500 /home/minecraft/restart.log > /home/minecraft/restart.log.tmp
    mv /home/minecraft/restart.log.tmp /home/minecraft/restart.log
    rm /home/minecraft/restart.log.tmp
    echo "$(date): 로그 파일 정리 완료" >> /home/minecraft/restart.log
fi

# 시스템 콜 레벨에서 파일 열기를 한 번만 실행하는 방식
# {
#     echo "$(date): 서버 재시작 완료 (이전 플레이어 수: $players)"
#     # 로그 파일이 1000줄 넘으면 최근 500줄만 유지
#     if [ $(wc -l < /home/minecraft/restart.log 2>/dev/null || echo 0) -gt 1000 ]; then
#         tail -n 500 /home/minecraft/restart.log > /home/minecraft/restart.log.tmp
#         mv /home/minecraft/restart.log.tmp /home/minecraft/restart.log
#         rm /home/minecraft/restart.log.tmp 
#     fi
# } >> /home/minecraft/restart.log
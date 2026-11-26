#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f .env ]; then
    (umask 077; printf 'DB_PASSWORD=%s\n' "$(openssl rand -hex 24)" > .env)
fi
set -a
source .env
set +a
sudo docker build -t cloudstock-api:v1 .
sudo docker network inspect cloudstock-net >/dev/null 2>&1 || sudo docker network create cloudstock-net
sudo docker volume create cloudstock-data
if ! sudo docker container inspect cloudstock-db >/dev/null 2>&1; then
    sudo docker run -d --name cloudstock-db --network cloudstock-net \
      --restart unless-stopped -e POSTGRES_DB=inventory -e POSTGRES_USER=cloudstock \
      -e POSTGRES_PASSWORD="$DB_PASSWORD" -v cloudstock-data:/var/lib/postgresql/data postgres:16-alpine
else
    sudo docker start cloudstock-db >/dev/null
fi
for i in $(seq 1 30); do
    if sudo docker exec cloudstock-db pg_isready -U cloudstock -d inventory >/dev/null 2>&1; then break; fi
    sleep 2
done
sudo docker exec cloudstock-db pg_isready -U cloudstock -d inventory
sudo docker rm -f cloudstock-api >/dev/null 2>&1 || true
sudo docker run -d --name cloudstock-api --network cloudstock-net --restart unless-stopped \
    -e DB_HOST=cloudstock-db -e DB_PASSWORD="$DB_PASSWORD" -p 127.0.0.1:8080:8080 cloudstock-api:v1
for i in $(seq 1 30); do
    if curl -fsS http://127.0.0.1:8080/health; then echo; exit 0; fi
    sleep 2
done
sudo docker logs cloudstock-api
exit 1

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Prefer non-root API image; fall back to ex02.
if ! docker image inspect dpl-python-api:ex06 >/dev/null 2>&1; then
  if ! docker image inspect dpl-python-api:ex02 >/dev/null 2>&1; then
    bash "${ROOT}/tests/solutions/02_first-dockerfile.sh"
    docker container rm --force dpl-ex02-api >/dev/null 2>&1 || true
  fi
  API_IMAGE='dpl-python-api:ex02'
else
  API_IMAGE='dpl-python-api:ex06'
fi

docker container rm --force dpl-ex07-api dpl-ex07-db >/dev/null 2>&1 || true
docker network rm dpl-ex07-front dpl-ex07-back >/dev/null 2>&1 || true

docker network create --label cloudsprocket.lab=docker dpl-ex07-front >/dev/null
docker network create --label cloudsprocket.lab=docker dpl-ex07-back >/dev/null

docker run -d \
  --name dpl-ex07-db \
  --label cloudsprocket.lab=docker \
  --network dpl-ex07-back \
  --network-alias db \
  valkey/valkey:8-alpine >/dev/null

docker run -d \
  --name dpl-ex07-api \
  --label cloudsprocket.lab=docker \
  --network dpl-ex07-back \
  -p 127.0.0.1:8213:8211 \
  "${API_IMAGE}" >/dev/null

docker network connect dpl-ex07-front dpl-ex07-api

# Wait for Valkey and API DNS path.
for _ in $(seq 1 40); do
  if docker exec dpl-ex07-api python -c \
    "import socket; s=socket.create_connection(('db', 6379), 2); s.close()" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.25
done

echo 'solution 07: API could not reach db:6379' >&2
exit 1

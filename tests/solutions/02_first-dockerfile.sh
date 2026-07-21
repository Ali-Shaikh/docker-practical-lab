#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

docker container rm --force dpl-ex02-api >/dev/null 2>&1 || true
docker image rm --force dpl-python-api:ex02 >/dev/null 2>&1 || true

docker build \
  -t dpl-python-api:ex02 \
  -f "${ROOT}/tests/solutions/02_first-dockerfile/Dockerfile" \
  "${ROOT}/apps/python-api" >/dev/null

docker run -d \
  --name dpl-ex02-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  dpl-python-api:ex02 >/dev/null

for _ in $(seq 1 40); do
  if curl -fsS --max-time 2 http://127.0.0.1:8211/health >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.25
done
echo 'solution 02: api did not become ready' >&2
exit 1

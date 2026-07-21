#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

docker container rm --force dpl-ex03-app >/dev/null 2>&1 || true
docker image rm --force dpl-node-app:ex03 >/dev/null 2>&1 || true

docker build \
  -t dpl-node-app:ex03 \
  -f "${ROOT}/tests/solutions/03_image-diet/Dockerfile" \
  "${ROOT}/apps/node-app" >/dev/null

docker run -d \
  --name dpl-ex03-app \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8212:8212 \
  dpl-node-app:ex03 >/dev/null

for _ in $(seq 1 40); do
  if curl -fsS --max-time 2 http://127.0.0.1:8212/health >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.25
done
echo 'solution 03: node app did not become ready' >&2
exit 1

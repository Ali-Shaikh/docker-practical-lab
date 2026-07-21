#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Ensure image from exercise 02 exists.
if ! docker image inspect dpl-python-api:ex02 >/dev/null 2>&1; then
  bash "${ROOT}/tests/solutions/02_first-dockerfile.sh"
  docker container rm --force dpl-ex02-api >/dev/null 2>&1 || true
fi

bash "${ROOT}/lab" registry start

docker container rm --force dpl-ex04-api dpl-ex02-api >/dev/null 2>&1 || true
docker tag dpl-python-api:ex02 127.0.0.1:8200/dpl-python-api:ex04
docker push 127.0.0.1:8200/dpl-python-api:ex04 >/dev/null
docker pull 127.0.0.1:8200/dpl-python-api:ex04 >/dev/null

docker run -d \
  --name dpl-ex04-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  127.0.0.1:8200/dpl-python-api:ex04 >/dev/null

for _ in $(seq 1 40); do
  if curl -fsS --max-time 2 http://127.0.0.1:8211/health >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.25
done
echo 'solution 04: registry-backed api did not become ready' >&2
exit 1

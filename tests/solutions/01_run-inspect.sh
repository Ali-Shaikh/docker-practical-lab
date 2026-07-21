#!/usr/bin/env bash
# Reference solution for exercise 01. Used by smoke; not shown to learners.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../../config/images.env
source "${ROOT}/config/images.env"

docker container rm --force dpl-ex01-nginx >/dev/null 2>&1 || true
docker pull "${NGINX_IMAGE}" >/dev/null
docker run -d \
  --name dpl-ex01-nginx \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8210:80 \
  "${NGINX_IMAGE}" >/dev/null

for _ in $(seq 1 40); do
  if curl -fsS --max-time 2 http://127.0.0.1:8210/ >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.25
done
echo 'solution 01: nginx did not become ready' >&2
exit 1

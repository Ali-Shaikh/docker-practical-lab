#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

docker container rm --force dpl-ex06-api dpl-ex02-api dpl-ex05-api >/dev/null 2>&1 || true
docker volume rm dpl-ex06-data >/dev/null 2>&1 || true
docker image rm --force dpl-python-api:ex06 >/dev/null 2>&1 || true

docker build \
  -t dpl-python-api:ex06 \
  -f "${ROOT}/tests/solutions/06_non-root/Dockerfile" \
  "${ROOT}/apps/python-api" >/dev/null 2>&1

docker volume create --label cloudsprocket.lab=docker dpl-ex06-data >/dev/null

# MSYS_NO_PATHCONV prevents Git Bash on Windows from rewriting volume mounts.
MSYS_NO_PATHCONV=1 docker run -d \
  --name dpl-ex06-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  -e DATA_DIR=/data \
  -v dpl-ex06-data:/data \
  dpl-python-api:ex06 >/dev/null

for _ in $(seq 1 40); do
  if curl -fsS --max-time 2 http://127.0.0.1:8211/ready >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

note_file="$(mktemp)"
printf '%s\n' '{"name":"nonroot","body":"uid 10001 can write"}' > "${note_file}"
curl -fsS -X POST http://127.0.0.1:8211/notes \
  -H 'Content-Type: application/json' \
  --data-binary @"${note_file}" >/dev/null
rm -f "${note_file}"

curl -fsS http://127.0.0.1:8211/notes | grep -q nonroot \
  || { echo 'solution 06: nonroot note missing' >&2; exit 1; }

exit 0

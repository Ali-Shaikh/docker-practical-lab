#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! docker image inspect dpl-python-api:ex02 >/dev/null 2>&1; then
  bash "${ROOT}/tests/solutions/02_first-dockerfile.sh"
  docker container rm --force dpl-ex02-api >/dev/null 2>&1 || true
fi

docker container rm --force dpl-ex05-api dpl-ex02-api dpl-ex04-api >/dev/null 2>&1 || true
docker volume rm dpl-ex05-data >/dev/null 2>&1 || true

docker volume create --label cloudsprocket.lab=docker dpl-ex05-data >/dev/null

# MSYS_NO_PATHCONV prevents Git Bash on Windows from rewriting volume mounts.
MSYS_NO_PATHCONV=1 docker run -d \
  --name dpl-ex05-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  -e DATA_DIR=/data \
  -v dpl-ex05-data:/data \
  dpl-python-api:ex02 >/dev/null

for _ in $(seq 1 40); do
  if curl -fsS --max-time 2 http://127.0.0.1:8211/health >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

note_file="$(mktemp)"
printf '%s\n' '{"name":"canary","body":"survives recreate"}' > "${note_file}"
curl -fsS -X POST http://127.0.0.1:8211/notes \
  -H 'Content-Type: application/json' \
  --data-binary @"${note_file}" >/dev/null
rm -f "${note_file}"

# Confirm the write landed before recreate.
curl -fsS http://127.0.0.1:8211/notes | grep -q canary \
  || { echo 'solution 05: canary not present before recreate' >&2; exit 1; }

docker container rm --force dpl-ex05-api >/dev/null

MSYS_NO_PATHCONV=1 docker run -d \
  --name dpl-ex05-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  -e DATA_DIR=/data \
  -v dpl-ex05-data:/data \
  dpl-python-api:ex02 >/dev/null

for _ in $(seq 1 40); do
  if curl -fsS --max-time 2 http://127.0.0.1:8211/notes 2>/dev/null | grep -q canary; then
    exit 0
  fi
  sleep 0.25
done
echo 'solution 05: canary note missing after recreate' >&2
exit 1

#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
ensure_lab_network
refuse_if_other_drill_active 'perm-wall'

# Need the non-root API image from exercise 06 solution if present; else build a minimal one.
if ! docker image inspect dpl-python-api:ex06 >/dev/null 2>&1; then
  bash "${ROOT}/tests/solutions/06_non-root.sh" >/dev/null
  docker container rm --force dpl-ex06-api >/dev/null 2>&1 || true
fi

docker container rm --force dpl-drill-perm >/dev/null 2>&1 || true
docker volume rm dpl-drill-perm-data >/dev/null 2>&1 || true
docker volume create --label "${LAB_LABEL}" dpl-drill-perm-data >/dev/null

# Seed volume as root-only.
MSYS_NO_PATHCONV=1 docker run --rm \
  --label "${LAB_LABEL}" \
  -v dpl-drill-perm-data:/data \
  "${PYTHON_IMAGE}" \
  sh -c 'mkdir -p /data && echo root-owned > /data/marker && chown -R 0:0 /data && chmod 700 /data'

MSYS_NO_PATHCONV=1 docker run -d \
  --name dpl-drill-perm \
  --label "${LAB_LABEL}" \
  --network "${NETWORK_NAME}" \
  -p 127.0.0.1:8243:8211 \
  -e DATA_DIR=/data \
  -e PORT=8211 \
  -v dpl-drill-perm-data:/data \
  dpl-python-api:ex06 >/dev/null

write_active_drill 'perm-wall'
printf 'Drill perm-wall is active. Non-root API cannot write /data on the volume.\n'

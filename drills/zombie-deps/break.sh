#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
ensure_lab_network
refuse_if_other_drill_active 'zombie-deps'

dir="${ROOT}/drills/zombie-deps/stack"
mkdir -p "${dir}"

if ! docker image inspect dpl-python-api:ex02 >/dev/null 2>&1; then
  bash "${ROOT}/tests/solutions/02_first-dockerfile.sh" >/dev/null
  docker container rm --force dpl-ex02-api >/dev/null 2>&1 || true
fi

cat >"${dir}/docker-compose.yml" <<'YML'
name: dpl-drill
services:
  valkey:
    image: valkey/valkey:8-alpine
    labels:
      cloudsprocket.lab: docker
    # healthcheck intentionally missing
  api:
    image: dpl-python-api:ex02
    labels:
      cloudsprocket.lab: docker
    ports:
      - "127.0.0.1:8244:8211"
    environment:
      PORT: "8211"
      DATA_DIR: /tmp/data
    depends_on:
      - valkey
    # no condition: service_healthy
YML

docker compose -f "${dir}/docker-compose.yml" down --remove-orphans >/dev/null 2>&1 || true
docker compose -f "${dir}/docker-compose.yml" up -d >/dev/null

write_active_drill 'zombie-deps'
printf 'Drill zombie-deps is active (compose project dpl-drill).\n'
printf 'Compose file: drills/zombie-deps/stack/docker-compose.yml\n'

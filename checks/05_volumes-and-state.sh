#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly CONTAINER='dpl-ex05-api'
readonly VOLUME='dpl-ex05-data'
readonly HOST_PORT='8211'

require_daemon
printf 'Checking exercise 05 (volumes-and-state)...\n'

assert_network_ready

if docker volume inspect "${VOLUME}" >/dev/null 2>&1; then
  vol_label="$(docker volume inspect --format '{{index .Labels "cloudsprocket.lab"}}' "${VOLUME}" 2>/dev/null || true)"
  if [[ "${vol_label}" == 'docker' ]]; then
    pass "volume ${VOLUME} exists and is labelled"
  else
    fail_item "volume ${VOLUME} must carry ${LAB_LABEL}"
  fi
else
  fail_item "volume ${VOLUME} was not found"
fi

assert_container_running "${CONTAINER}"
assert_lab_label_on_container "${CONTAINER}"
assert_loopback_port_publish "${CONTAINER}" "${HOST_PORT}"

mounts="$(docker container inspect --format '{{json .Mounts}}' "${CONTAINER}" 2>/dev/null || true)"
if [[ "${mounts}" == *"${VOLUME}"* ]] && [[ "${mounts}" == *'"Destination":"/data"'* || "${mounts}" == *'"Destination": "/data"'* ]]; then
  pass "container mounts ${VOLUME} at /data"
else
  # Docker JSON uses Destination key without space
  if [[ "${mounts}" == *"${VOLUME}"* ]] && [[ "${mounts}" == *'/data'* ]]; then
    pass "container mounts ${VOLUME} involving /data"
  else
    fail_item "container ${CONTAINER} must mount volume ${VOLUME} at /data"
  fi
fi

assert_http_ok "http://127.0.0.1:${HOST_PORT}/notes" 'canary'

finish_check '05'

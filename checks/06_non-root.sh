#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly IMAGE='dpl-python-api:ex06'
readonly CONTAINER='dpl-ex06-api'
readonly VOLUME='dpl-ex06-data'
readonly HOST_PORT='8211'

require_daemon
printf 'Checking exercise 06 (non-root)...\n'

assert_network_ready
assert_image_exists "${IMAGE}"
assert_lab_label_on_image "${IMAGE}"
assert_container_running "${CONTAINER}"
assert_lab_label_on_container "${CONTAINER}"
assert_loopback_port_publish "${CONTAINER}" "${HOST_PORT}"

user="$(docker container inspect --format '{{.Config.User}}' "${CONTAINER}" 2>/dev/null || true)"
if [[ "${user}" == '10001' || "${user}" == '10001:10001' ]]; then
  pass "container ${CONTAINER} runs as non-root user ${user}"
else
  fail_item "container ${CONTAINER} must run as user 10001 (got '${user}')"
fi

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

mounts="$(docker container inspect --format '{{json .Mounts}}' "${CONTAINER}" 2>/dev/null || true)"
if [[ "${mounts}" == *"${VOLUME}"* ]] && [[ "${mounts}" == *'/data'* ]]; then
  pass "container mounts ${VOLUME} involving /data"
else
  fail_item "container ${CONTAINER} must mount volume ${VOLUME} at /data"
fi

assert_http_ok "http://127.0.0.1:${HOST_PORT}/ready" 'ready'
assert_http_ok "http://127.0.0.1:${HOST_PORT}/health" '"status"'

# Prefer an existing learner note; otherwise attempt a write to prove permissions.
notes_body="$(curl -fsS --max-time 5 "http://127.0.0.1:${HOST_PORT}/notes" 2>/dev/null || true)"
if [[ "${notes_body}" == *'nonroot'* ]] || [[ "${notes_body}" == *'canary'* ]]; then
  pass "data directory already holds a note written by the non-root process"
else
  note_file="$(mktemp)"
  printf '%s\n' '{"name":"check06","body":"write probe"}' > "${note_file}"
  if curl -fsS --max-time 5 -X POST "http://127.0.0.1:${HOST_PORT}/notes" \
    -H 'Content-Type: application/json' \
    --data-binary @"${note_file}" >/dev/null 2>&1; then
    pass "POST /notes succeeded (non-root can write DATA_DIR)"
  else
    fail_item "POST /notes failed; non-root process cannot write the data volume"
  fi
  rm -f "${note_file}"
fi

finish_check '06'

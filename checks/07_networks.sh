#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly FRONT='dpl-ex07-front'
readonly BACK='dpl-ex07-back'
readonly API='dpl-ex07-api'
readonly DB='dpl-ex07-db'

require_daemon
printf 'Checking exercise 07 (networks)...\n'

assert_network_ready

for net in "${FRONT}" "${BACK}"; do
  if docker network inspect "${net}" >/dev/null 2>&1; then
    net_label="$(docker network inspect --format '{{index .Labels "cloudsprocket.lab"}}' "${net}" 2>/dev/null || true)"
    if [[ "${net_label}" == 'docker' ]]; then
      pass "network ${net} exists and is labelled"
    else
      fail_item "network ${net} must carry ${LAB_LABEL}"
    fi
  else
    fail_item "network ${net} was not found"
  fi
done

assert_container_running "${API}"
assert_lab_label_on_container "${API}"
assert_container_running "${DB}"
assert_lab_label_on_container "${DB}"

# API must be on both networks.
api_nets="$(docker container inspect --format '{{json .NetworkSettings.Networks}}' "${API}" 2>/dev/null || true)"
if [[ "${api_nets}" == *"${FRONT}"* ]] && [[ "${api_nets}" == *"${BACK}"* ]]; then
  pass "container ${API} is attached to front and back networks"
else
  fail_item "container ${API} must be attached to both ${FRONT} and ${BACK}"
fi

# DB must be on back only (not front).
db_nets="$(docker container inspect --format '{{json .NetworkSettings.Networks}}' "${DB}" 2>/dev/null || true)"
if [[ "${db_nets}" == *"${BACK}"* ]] && [[ "${db_nets}" != *"${FRONT}"* ]]; then
  pass "container ${DB} is on ${BACK} only"
else
  fail_item "container ${DB} must be attached to ${BACK} only (not ${FRONT})"
fi

# API reaches db:6379 by Docker DNS name.
if docker exec "${API}" python -c \
  "import socket; s=socket.create_connection(('db', 6379), 3); s.close()" >/dev/null 2>&1; then
  pass "API can open TCP to db:6379"
else
  # Some images may lack python; try a busybox-style fallback via getent + /dev/tcp is bash-only.
  if docker exec "${API}" sh -c 'getent hosts db >/dev/null 2>&1 || nslookup db >/dev/null 2>&1' >/dev/null 2>&1 \
    && docker exec "${API}" sh -c 'command -v nc >/dev/null && nc -z -w 3 db 6379' >/dev/null 2>&1; then
    pass "API can reach db:6379"
  else
    fail_item "API container cannot reach db:6379 by name on the back network"
  fi
fi

# Front-only client must not reach db.
set +e
front_out="$(docker run --rm \
  --label cloudsprocket.lab=docker \
  --network "${FRONT}" \
  python:3.14-slim \
  python -c "import socket; socket.create_connection(('db', 6379), 3)" 2>&1)"
front_status=$?
set -e
if (( front_status != 0 )); then
  pass "front-only client cannot reach db:6379"
else
  fail_item "front-only client unexpectedly reached db:6379 (isolation broken)"
fi
unset front_out

finish_check '07'

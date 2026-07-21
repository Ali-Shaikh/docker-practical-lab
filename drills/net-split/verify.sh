#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
failures=0
pass() { printf '  pass  %s\n' "$*"; }
fail_item() { printf '  fail  %s\n' "$*" >&2; failures=$((failures + 1)); }

printf 'Verifying net-split...\n'

assert_running() {
  if docker container inspect --format '{{.State.Running}}' "$1" 2>/dev/null | grep -qx true; then
    pass "container $1 is running"
  else
    fail_item "container $1 is not running"
  fi
}
assert_running dpl-drill-api
assert_running dpl-drill-db

api_nets="$(docker container inspect --format '{{json .NetworkSettings.Networks}}' dpl-drill-api 2>/dev/null || true)"
if [[ "${api_nets}" == *'dpl-drill-back'* ]]; then
  pass 'API is attached to dpl-drill-back'
else
  fail_item 'API must be attached to dpl-drill-back (and may stay on front)'
fi

db_nets="$(docker container inspect --format '{{json .NetworkSettings.Networks}}' dpl-drill-db 2>/dev/null || true)"
if [[ "${db_nets}" == *'dpl-drill-back'* ]] && [[ "${db_nets}" != *'dpl-drill-front'* ]]; then
  pass 'db stays on back network only'
else
  fail_item 'db must remain on dpl-drill-back only'
fi

if docker exec dpl-drill-api python -c "import socket; s=socket.create_connection(('db',6379),3); s.close()" >/dev/null 2>&1; then
  pass 'API can open TCP to db:6379'
else
  fail_item 'API cannot reach db:6379 by name'
fi

if (( failures == 0 )); then
  clear_active_drill
  printf '\nnet-split: repaired.\n'
  exit 0
fi
printf '\nnet-split: still broken (%s check(s) failed).\n' "${failures}" >&2
exit 1

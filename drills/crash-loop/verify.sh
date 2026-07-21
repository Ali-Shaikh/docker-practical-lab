#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
failures=0
pass() { printf '  pass  %s\n' "$*"; }
fail_item() { printf '  fail  %s\n' "$*" >&2; failures=$((failures + 1)); }

printf 'Verifying crash-loop...\n'

if docker container inspect --format '{{.State.Running}}' dpl-drill-crash 2>/dev/null | grep -qx true; then
  pass 'container dpl-drill-crash is running'
else
  fail_item 'container dpl-drill-crash is not running'
fi

label="$(docker container inspect --format '{{index .Config.Labels "cloudsprocket.lab"}}' dpl-drill-crash 2>/dev/null || true)"
if [[ "${label}" == 'docker' ]]; then
  pass 'container still carries the lab label'
else
  fail_item 'container must keep label cloudsprocket.lab=docker'
fi

if curl -fsS --max-time 5 http://127.0.0.1:8240/health 2>/dev/null | grep -q '"status"'; then
  pass 'HTTP /health answers on 127.0.0.1:8240'
else
  fail_item 'http://127.0.0.1:8240/health did not return a healthy response'
fi

if (( failures == 0 )); then
  clear_active_drill
  printf '\ncrash-loop: repaired.\n'
  exit 0
fi
printf '\ncrash-loop: still broken (%s check(s) failed).\n' "${failures}" >&2
exit 1

#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
refuse_if_mismatched_active_drill 'port-tangle'
failures=0
pass() { printf '  pass  %s\n' "$*"; }
fail_item() { printf '  fail  %s\n' "$*" >&2; failures=$((failures + 1)); }

printf 'Verifying port-tangle...\n'

if docker container inspect dpl-drill-squatter >/dev/null 2>&1; then
  fail_item 'squatter container dpl-drill-squatter must be removed'
else
  pass 'squatter container is gone'
fi

if docker container inspect --format '{{.State.Running}}' dpl-drill-port 2>/dev/null | grep -qx true; then
  pass 'dpl-drill-port is running'
else
  fail_item 'dpl-drill-port must be running'
fi

ports="$(docker container inspect --format '{{json .HostConfig.PortBindings}}' dpl-drill-port 2>/dev/null || true)"
if [[ "${ports}" == *'"HostIp":"127.0.0.1"'* ]] && [[ "${ports}" == *'"HostPort":"8241"'* ]]; then
  pass 'dpl-drill-port publishes 8241 on 127.0.0.1'
else
  fail_item 'dpl-drill-port must publish host port 8241 on 127.0.0.1'
fi

if curl -fsS --max-time 5 -o /dev/null http://127.0.0.1:8241/; then
  pass 'HTTP answers on 127.0.0.1:8241'
else
  fail_item 'http://127.0.0.1:8241/ did not succeed'
fi

if (( failures == 0 )); then
  clear_active_drill 'port-tangle'
  printf '\nport-tangle: repaired.\n'
  exit 0
fi
printf '\nport-tangle: still broken (%s check(s) failed).\n' "${failures}" >&2
exit 1

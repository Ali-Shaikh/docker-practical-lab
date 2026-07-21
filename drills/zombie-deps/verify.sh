#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
failures=0
pass() { printf '  pass  %s\n' "$*"; }
fail_item() { printf '  fail  %s\n' "$*" >&2; failures=$((failures + 1)); }

printf 'Verifying zombie-deps...\n'
compose_file="${ROOT}/drills/zombie-deps/stack/docker-compose.yml"

if [[ ! -f "${compose_file}" ]]; then
  fail_item "compose file missing at ${compose_file}"
  printf '\nzombie-deps: still broken.\n' >&2
  exit 1
fi

cfg="$(docker compose -f "${compose_file}" config 2>/dev/null || true)"
if [[ "${cfg}" == *'condition: service_healthy'* ]] || [[ "${cfg}" == *'service_healthy'* ]]; then
  pass 'depends_on uses service_healthy'
else
  fail_item 'api must depend on valkey with condition service_healthy'
fi

if [[ "${cfg}" == *'healthcheck'* ]] || [[ "${cfg}" == *'test:'* ]]; then
  pass 'valkey defines a healthcheck in compose config'
else
  fail_item 'valkey service must define a healthcheck'
fi

if curl -fsS --max-time 5 http://127.0.0.1:8244/health 2>/dev/null | grep -q status; then
  pass 'API health endpoint answers on 8244'
else
  fail_item 'http://127.0.0.1:8244/health failed'
fi

if (( failures == 0 )); then
  clear_active_drill
  printf '\nzombie-deps: repaired.\n'
  exit 0
fi
printf '\nzombie-deps: still broken (%s check(s) failed).\n' "${failures}" >&2
exit 1

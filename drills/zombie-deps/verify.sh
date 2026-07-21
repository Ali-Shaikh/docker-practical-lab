#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
refuse_if_mismatched_active_drill 'zombie-deps'
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

cfg_json="$(docker compose -f "${compose_file}" config --format json 2>/dev/null || true)"
if [[ -z "${cfg_json}" ]]; then
  fail_item 'docker compose config --format json failed for the drill stack'
else
  # Validate the api->valkey relationship and valkey healthcheck specifically,
  # not a loose substring match across the whole file.
  relation="$(
    printf '%s' "${cfg_json}" | MSYS_NO_PATHCONV=1 docker run --rm -i \
      --label "${LAB_LABEL}" \
      "${PYTHON_IMAGE}" \
      python -c '
import json, sys
cfg = json.load(sys.stdin)
services = cfg.get("services") or {}
valkey = services.get("valkey") or {}
api = services.get("api") or {}
hc = valkey.get("healthcheck")
deps = api.get("depends_on")
healthy = False
if isinstance(deps, dict):
    entry = deps.get("valkey")
    if isinstance(entry, dict) and entry.get("condition") == "service_healthy":
        healthy = True
print("hc=" + ("yes" if hc else "no"))
print("dep=" + ("yes" if healthy else "no"))
'
  )"
  if printf '%s\n' "${relation}" | grep -qx 'hc=yes'; then
    pass 'valkey service defines a healthcheck'
  else
    fail_item 'valkey service must define a healthcheck'
  fi
  if printf '%s\n' "${relation}" | grep -qx 'dep=yes'; then
    pass 'api depends on valkey with condition service_healthy'
  else
    fail_item 'api must depend on valkey with condition: service_healthy'
  fi
fi

if curl -fsS --max-time 5 http://127.0.0.1:8244/health 2>/dev/null | grep -q status; then
  pass 'API health endpoint answers on 8244'
else
  fail_item 'http://127.0.0.1:8244/health failed'
fi

if (( failures == 0 )); then
  clear_active_drill 'zombie-deps'
  printf '\nzombie-deps: repaired.\n'
  exit 0
fi
printf '\nzombie-deps: still broken (%s check(s) failed).\n' "${failures}" >&2
exit 1

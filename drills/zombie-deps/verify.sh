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
  # Scope checks to valkey healthcheck and api->valkey service_healthy only.
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
hc = valkey.get("healthcheck") or {}
disabled = hc.get("disable") is True
test = hc.get("test")
tokens = [str(x).lower() for x in test] if isinstance(test, list) else []
joined = " ".join(tokens)
# Require an enabled check that actually pings Valkey, not echo/help no-ops.
# Accept CMD form ["CMD","valkey-cli","ping"] or shell form containing "valkey-cli ping".
hc_ok = (
    (not disabled)
    and bool(tokens)
    and "valkey-cli" in joined
    and "ping" in joined
    and "echo" not in joined
    and "--help" not in joined
    and "true" not in tokens
)
deps = api.get("depends_on")
dep_ok = False
if isinstance(deps, dict):
    entry = deps.get("valkey")
    if isinstance(entry, dict) and entry.get("condition") == "service_healthy":
        dep_ok = True
print("hc=" + ("yes" if hc_ok else "no"))
print("dep=" + ("yes" if dep_ok else "no"))
'
  )"
  if printf '%s\n' "${relation}" | grep -qx 'hc=yes'; then
    pass 'valkey defines an enabled ping healthcheck'
  else
    fail_item 'valkey must define an enabled healthcheck that pings (for example valkey-cli ping)'
  fi
  if printf '%s\n' "${relation}" | grep -qx 'dep=yes'; then
    pass 'api depends on valkey with condition service_healthy'
  else
    fail_item 'api must depend on valkey with condition: service_healthy'
  fi
fi

# Apply the compose file so a repaired depends_on/healthcheck takes effect, then
# require Valkey to report healthy (proves the check is not a no-op).
if ! docker compose -f "${compose_file}" up -d >/dev/null 2>&1; then
  fail_item 'docker compose up -d failed for the repaired stack'
else
  valkey_healthy=0
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    cid="$(docker compose -f "${compose_file}" ps -q valkey 2>/dev/null | head -n1 || true)"
    if [[ -n "${cid}" ]]; then
      status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${cid}" 2>/dev/null || true)"
      if [[ "${status}" == 'healthy' ]]; then
        valkey_healthy=1
        break
      fi
    fi
    sleep 1
  done
  if (( valkey_healthy == 1 )); then
    pass 'valkey container reaches a healthy state'
  else
    fail_item 'valkey never became healthy after compose up (healthcheck still broken?)'
  fi
fi

api_up=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if curl -fsS --max-time 2 http://127.0.0.1:8244/health 2>/dev/null | grep -q status; then
    api_up=1
    break
  fi
  sleep 1
done
if (( api_up == 1 )); then
  pass 'API health endpoint answers on 8244 after healthy dependency'
else
  fail_item 'http://127.0.0.1:8244/health failed after compose up'
fi

if (( failures == 0 )); then
  clear_active_drill 'zombie-deps'
  printf '\nzombie-deps: repaired.\n'
  exit 0
fi
printf '\nzombie-deps: still broken (%s check(s) failed).\n' "${failures}" >&2
exit 1

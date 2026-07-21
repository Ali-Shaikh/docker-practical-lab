#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
refuse_if_mismatched_active_drill 'perm-wall'
failures=0
pass() { printf '  pass  %s\n' "$*"; }
fail_item() { printf '  fail  %s\n' "$*" >&2; failures=$((failures + 1)); }

printf 'Verifying perm-wall...\n'

user="$(docker container inspect --format '{{.Config.User}}' dpl-drill-perm 2>/dev/null || true)"
if [[ "${user}" == *'10001'* ]]; then
  pass "container still runs as non-root (${user})"
else
  fail_item "container must keep a non-root user (expected uid 10001), got '${user}'"
fi

if curl -fsS --max-time 5 http://127.0.0.1:8243/ready 2>/dev/null | grep -q ready; then
  pass '/ready reports writable data directory'
else
  fail_item 'http://127.0.0.1:8243/ready is not ready (volume still not writable?)'
fi

note_file="$(mktemp)"
printf '%s\n' '{"name":"permok","body":"ok"}' > "${note_file}"
if curl -fsS -X POST http://127.0.0.1:8243/notes \
  -H 'Content-Type: application/json' \
  --data-binary @"${note_file}" >/dev/null 2>&1; then
  pass 'non-root process can create a note'
else
  fail_item 'POST /notes failed for the non-root API'
fi
rm -f "${note_file}"

if (( failures == 0 )); then
  clear_active_drill 'perm-wall'
  printf '\nperm-wall: repaired.\n'
  exit 0
fi
printf '\nperm-wall: still broken (%s check(s) failed).\n' "${failures}" >&2
exit 1

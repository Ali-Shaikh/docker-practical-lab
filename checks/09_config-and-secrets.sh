#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly IMAGE='dpl-secret-demo:ex09'
readonly SECRET_VALUE='dpl-ex09-do-not-leak'

require_daemon
printf 'Checking exercise 09 (config-and-secrets)...\n'

assert_image_exists "${IMAGE}"
assert_lab_label_on_image "${IMAGE}"

history_text="$(docker history --no-trunc "${IMAGE}" 2>/dev/null || true)"
if [[ "${history_text}" == *"${SECRET_VALUE}"* ]]; then
  fail_item "docker history for ${IMAGE} still contains the secret value"
else
  pass "docker history does not contain the secret value"
fi

# Full image config JSON (Env, Cmd, Labels, history-adjacent config).
config_json="$(docker image inspect "${IMAGE}" 2>/dev/null || true)"
if [[ "${config_json}" == *"${SECRET_VALUE}"* ]]; then
  fail_item "image inspect output for ${IMAGE} still contains the secret value"
else
  pass "image config/inspect does not contain the secret value"
fi

# Marker must prove the secret was consumed at build time without storing it.
marker="$(docker run --rm --label cloudsprocket.lab=docker "${IMAGE}" 2>/dev/null || true)"
# Also try reading a conventional marker path if CMD is not the marker.
if [[ "${marker}" == *'secret-ok'* ]]; then
  pass "image produces secret-ok marker without embedding the secret"
else
  marker_file="$(docker run --rm --label cloudsprocket.lab=docker --entrypoint cat "${IMAGE}" /app/secret-status 2>/dev/null || true)"
  if [[ "${marker_file}" == *'secret-ok'* ]]; then
    pass "image contains /app/secret-status marker from the secret mount build"
  else
    fail_item "image must prove the BuildKit secret was used (marker 'secret-ok') without storing the secret"
  fi
fi

finish_check '09'

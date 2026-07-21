#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly REGISTRY='dpl-registry'
readonly CONTAINER='dpl-ex04-api'
readonly HOST_PORT='8211'
readonly REGISTRY_URL='http://127.0.0.1:8200'

require_daemon
printf 'Checking exercise 04 (tag-and-registry)...\n'

assert_network_ready
assert_container_running "${REGISTRY}"
assert_lab_label_on_container "${REGISTRY}"

catalog="$(curl -fsS --max-time 5 "${REGISTRY_URL}/v2/_catalog" 2>/dev/null || true)"
if [[ "${catalog}" == *'dpl-python-api'* ]]; then
  pass 'registry catalog lists dpl-python-api'
else
  fail_item 'registry catalog does not list dpl-python-api; push 127.0.0.1:8200/dpl-python-api:ex04'
fi

tags="$(curl -fsS --max-time 5 "${REGISTRY_URL}/v2/dpl-python-api/tags/list" 2>/dev/null || true)"
if [[ "${tags}" == *'ex04'* ]]; then
  pass 'registry has tag ex04 for dpl-python-api'
else
  fail_item 'registry is missing tag ex04 for dpl-python-api'
fi

assert_container_running "${CONTAINER}"
assert_lab_label_on_container "${CONTAINER}"
assert_loopback_port_publish "${CONTAINER}" "${HOST_PORT}"
assert_http_ok "http://127.0.0.1:${HOST_PORT}/health" '"status"'

finish_check '04'

#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly IMAGE='dpl-python-api:ex02'
readonly CONTAINER='dpl-ex02-api'
readonly HOST_PORT='8211'

require_daemon
printf 'Checking exercise 02 (first-dockerfile)...\n'

assert_network_ready
assert_image_exists "${IMAGE}"
assert_lab_label_on_image "${IMAGE}"
assert_container_running "${CONTAINER}"
assert_lab_label_on_container "${CONTAINER}"
assert_loopback_port_publish "${CONTAINER}" "${HOST_PORT}"
assert_http_ok "http://127.0.0.1:${HOST_PORT}/health" '"status"'
assert_http_ok "http://127.0.0.1:${HOST_PORT}/ready" 'ready'

finish_check '02'

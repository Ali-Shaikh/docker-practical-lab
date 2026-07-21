#!/usr/bin/env bash
# Exercise 01 check: live nginx container, label, loopback port, HTTP.
set -Eeuo pipefail
# shellcheck disable=SC1091
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly CONTAINER='dpl-ex01-nginx'
readonly HOST_PORT='8210'

require_daemon
printf 'Checking exercise 01 (run-inspect)...\n'

assert_network_ready
assert_container_running "${CONTAINER}"
assert_lab_label_on_container "${CONTAINER}"
assert_loopback_port_publish "${CONTAINER}" "${HOST_PORT}"
assert_http_ok "http://127.0.0.1:${HOST_PORT}/"

finish_check '01'

#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly IMAGE='dpl-node-app:ex03'
readonly CONTAINER='dpl-ex03-app'
readonly HOST_PORT='8212'
# Ceiling covers both containerd and graphdriver reporting on a correct
# alpine multi-stage build with production node_modules only.
# Reference solution measured ~35-45 MiB; 1.5x loose bound ≈ 220 MiB on graphdriver; containerd is smaller.
readonly MAX_IMAGE_BYTES=$((220 * 1024 * 1024))

require_daemon
printf 'Checking exercise 03 (image-diet)...\n'

assert_network_ready
assert_image_exists "${IMAGE}"
assert_lab_label_on_image "${IMAGE}"
assert_image_size_under "${IMAGE}" "${MAX_IMAGE_BYTES}"
assert_container_running "${CONTAINER}"
assert_lab_label_on_container "${CONTAINER}"
assert_loopback_port_publish "${CONTAINER}" "${HOST_PORT}"
assert_http_ok "http://127.0.0.1:${HOST_PORT}/health" '"status"'

finish_check '03'

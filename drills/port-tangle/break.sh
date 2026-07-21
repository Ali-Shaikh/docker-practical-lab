#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
ensure_lab_network
refuse_if_other_drill_active 'port-tangle'

docker container rm --force dpl-drill-port dpl-drill-squatter >/dev/null 2>&1 || true

# Squatter holds the intended host port.
docker run -d \
  --name dpl-drill-squatter \
  --label "${LAB_LABEL}" \
  --network "${NETWORK_NAME}" \
  -p 127.0.0.1:8241:80 \
  "${NGINX_IMAGE}" >/dev/null

# Learner container uses a reversed mapping (container:host style mistake).
# Publish 80 on host to 8241 in container (wrong); use a free host port 18241
# so both can exist; the ticket still says the service should be on 8241.
docker run -d \
  --name dpl-drill-port \
  --label "${LAB_LABEL}" \
  --network "${NETWORK_NAME}" \
  -p 127.0.0.1:18241:80 \
  "${NGINX_IMAGE}" >/dev/null

write_active_drill 'port-tangle'
printf 'Drill port-tangle is active.\n'
printf 'dpl-drill-squatter holds 8241; dpl-drill-port is published on 18241.\n'
printf 'Make dpl-drill-port the healthy service on 127.0.0.1:8241 and remove the squatter.\n'

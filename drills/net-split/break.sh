#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
ensure_lab_network
refuse_if_other_drill_active 'net-split'

docker container rm --force dpl-drill-api dpl-drill-db >/dev/null 2>&1 || true
docker network rm dpl-drill-front dpl-drill-back >/dev/null 2>&1 || true

docker network create --label "${LAB_LABEL}" dpl-drill-front >/dev/null
docker network create --label "${LAB_LABEL}" dpl-drill-back >/dev/null

docker run -d \
  --name dpl-drill-db \
  --hostname db \
  --label "${LAB_LABEL}" \
  --network dpl-drill-back \
  valkey/valkey:8-alpine >/dev/null

# API only on front network: cannot resolve/reach db.
docker run -d \
  --name dpl-drill-api \
  --label "${LAB_LABEL}" \
  --network dpl-drill-front \
  -p 127.0.0.1:8242:8211 \
  -e PORT=8211 \
  "${PYTHON_IMAGE}" \
  python -c 'import http.server; http.server.ThreadingHTTPServer(("0.0.0.0",8211), http.server.SimpleHTTPRequestHandler).serve_forever()' >/dev/null

write_active_drill 'net-split'
printf 'Drill net-split is active. API is on dpl-drill-front; db is only on dpl-drill-back.\n'

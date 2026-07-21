#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
ensure_lab_network
refuse_if_other_drill_active 'crash-loop'

docker container rm --force dpl-drill-crash >/dev/null 2>&1 || true
docker image rm --force dpl-drill-crash:broken >/dev/null 2>&1 || true

tmpdir="$(mktemp -d)"
cat >"${tmpdir}/app.py" <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.rstrip("/") == "/health":
            body = json.dumps({"status": "ok"}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()
    def log_message(self, *args):
        pass

HTTPServer(("0.0.0.0", 8211), H).serve_forever()
PY
cat >"${tmpdir}/Dockerfile" <<'DF'
FROM python:3.14-slim
LABEL cloudsprocket.lab=docker
WORKDIR /app
COPY app.py .
# Broken on purpose: wrong module path so the container exits immediately.
CMD ["python", "-m", "missing_app"]
DF

docker build -t dpl-drill-crash:broken "${tmpdir}" >/dev/null
rm -rf "${tmpdir}"

docker run -d \
  --name dpl-drill-crash \
  --label "${LAB_LABEL}" \
  --network "${NETWORK_NAME}" \
  --restart on-failure:5 \
  -p 127.0.0.1:8240:8211 \
  dpl-drill-crash:broken >/dev/null

write_active_drill 'crash-loop'
printf 'Drill crash-loop is active. Container dpl-drill-crash is failing to stay up.\n'
printf 'Read drills/crash-loop/brief.md, then run: ./lab verify crash-loop\n'

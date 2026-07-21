#!/usr/bin/env bash
# Native acceptance for the three sample apps (PR 2).
# Each app must work without Docker exactly as its README claims.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

cleanup() {
  if [[ -n "${PYTHON_PID:-}" ]] && kill -0 "$PYTHON_PID" 2>/dev/null; then
    kill "$PYTHON_PID" 2>/dev/null || true
    wait "$PYTHON_PID" 2>/dev/null || true
  fi
  if [[ -n "${NODE_PID:-}" ]] && kill -0 "$NODE_PID" 2>/dev/null; then
    kill "$NODE_PID" 2>/dev/null || true
    wait "$NODE_PID" 2>/dev/null || true
  fi
  if [[ -n "${STATIC_PID:-}" ]] && kill -0 "$STATIC_PID" 2>/dev/null; then
    kill "$STATIC_PID" 2>/dev/null || true
    wait "$STATIC_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

wait_http() {
  local url="$1"
  local attempts="${2:-40}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  echo "timed out waiting for $url" >&2
  return 1
}

echo "==> python-api native check"
PORT=18211 DATA_DIR="$ROOT/apps/python-api/data-ci" python3 "$ROOT/apps/python-api/app.py" &
PYTHON_PID=$!
wait_http "http://127.0.0.1:18211/health"
curl -fsS "http://127.0.0.1:18211/ready" | grep -q '"status": "ready"'
curl -fsS -X POST "http://127.0.0.1:18211/notes" \
  -H "Content-Type: application/json" \
  -d '{"name":"ci-note","body":"native works"}' | grep -q '"created": "ci-note"'
curl -fsS "http://127.0.0.1:18211/notes" | grep -q 'ci-note'
test -f "$ROOT/apps/python-api/data-ci/ci-note"
kill "$PYTHON_PID"
wait "$PYTHON_PID" 2>/dev/null || true
PYTHON_PID=""
rm -rf "$ROOT/apps/python-api/data-ci"
echo "python-api OK"

echo "==> node-app native check"
(
  cd "$ROOT/apps/node-app"
  npm install --no-fund --no-audit
  npm run build
)
PORT=18212 node "$ROOT/apps/node-app/dist/server.js" &
NODE_PID=$!
wait_http "http://127.0.0.1:18212/health"
curl -fsS "http://127.0.0.1:18212/greet?name=CI" | grep -q 'Hello, CI'
curl -fsS -X POST "http://127.0.0.1:18212/echo" \
  -H "Content-Type: application/json" \
  -d '{"message":"native works"}' | grep -q 'native works'
kill "$NODE_PID"
wait "$NODE_PID" 2>/dev/null || true
NODE_PID=""
echo "node-app OK"

echo "==> static-site native check"
(
  cd "$ROOT/apps/static-site"
  python3 -m http.server 18080 --bind 127.0.0.1
) &
STATIC_PID=$!
wait_http "http://127.0.0.1:18080/"
curl -fsS "http://127.0.0.1:18080/" | grep -qi "image versus container"
curl -fsS -o /dev/null -w "%{http_code}" "http://127.0.0.1:18080/styles.css" | grep -q 200
kill "$STATIC_PID"
wait "$STATIC_PID" 2>/dev/null || true
STATIC_PID=""
echo "static-site OK"

echo "Sample apps native acceptance passed."

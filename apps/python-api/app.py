#!/usr/bin/env python3
"""Minimal HTTP API used by the Docker Practical Lab sample track.

Stdlib only so learners can run it before they meet Dockerfiles or pip.
Later exercises containerise this service, mount its data directory, and
reuse the /health and /ready endpoints as Kubernetes-style probes.
"""

from __future__ import annotations

import json
import os
import re
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

PORT = int(os.environ.get("PORT", "8211"))
DATA_DIR = Path(os.environ.get("DATA_DIR", "data")).resolve()
STARTED_AT = time.time()
NOTE_NAME = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$")
# Keep request bodies small; this is a teaching API, not a file upload service.
MAX_BODY_BYTES = 64 * 1024


def ensure_data_dir() -> Path:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    return DATA_DIR


def data_dir_writable() -> bool:
    try:
        ensure_data_dir()
        probe = DATA_DIR / ".write-probe"
        probe.write_text("ok\n", encoding="utf-8")
        probe.unlink(missing_ok=True)
        return True
    except OSError:
        return False


def list_notes() -> list[str]:
    ensure_data_dir()
    return sorted(
        path.name
        for path in DATA_DIR.iterdir()
        if path.is_file() and not path.name.startswith(".")
    )


def write_note(name: str, body: str) -> None:
    if not NOTE_NAME.fullmatch(name):
        raise ValueError(
            "note name must be 1-64 chars of letters, digits, dot, underscore or hyphen"
        )
    ensure_data_dir()
    path = DATA_DIR / name
    path.write_text(body, encoding="utf-8")


class Handler(BaseHTTPRequestHandler):
    server_version = "docker-practical-lab-python-api/0.1"

    def log_message(self, format: str, *args) -> None:
        # Keep lab output quiet and greppable.
        print(f"{self.command} {self.path} -> {args[1] if len(args) > 1 else ''}".strip())

    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8") + b"\n"
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        length_header = self.headers.get("Content-Length", "0").strip() or "0"
        try:
            length = int(length_header)
        except ValueError as exc:
            raise ValueError("Content-Length must be an integer") from exc
        if length < 0:
            raise ValueError("Content-Length must be non-negative")
        if length > MAX_BODY_BYTES:
            raise ValueError(f"request body exceeds {MAX_BODY_BYTES} bytes")
        raw = self.rfile.read(length) if length else b"{}"
        if not raw:
            return {}
        try:
            value = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ValueError(f"body must be JSON: {exc}") from exc
        if not isinstance(value, dict):
            raise ValueError("JSON body must be an object")
        return value

    def do_GET(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"

        if path == "/":
            self._send_json(
                200,
                {
                    "service": "python-api",
                    "message": "Sample API for the Docker Practical Lab",
                    "endpoints": {
                        "GET /health": "liveness: process is up",
                        "GET /ready": "readiness: data directory is writable",
                        "GET /notes": "list notes written under DATA_DIR",
                        "POST /notes": 'create a note: {"name": "hello", "body": "text"}',
                    },
                    "data_dir": str(DATA_DIR),
                    "uptime_seconds": round(time.time() - STARTED_AT, 1),
                },
            )
            return

        if path == "/health":
            # Liveness: the process answers. Used by later container healthchecks.
            self._send_json(200, {"status": "ok"})
            return

        if path == "/ready":
            # Readiness: dependencies the app needs (here, a writable data dir).
            if data_dir_writable():
                self._send_json(200, {"status": "ready", "data_dir": str(DATA_DIR)})
            else:
                self._send_json(
                    503,
                    {
                        "status": "not_ready",
                        "reason": "data directory is not writable",
                        "data_dir": str(DATA_DIR),
                    },
                )
            return

        if path == "/notes":
            self._send_json(200, {"notes": list_notes()})
            return

        self._send_json(404, {"error": "not found", "path": path})

    def do_POST(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"
        if path != "/notes":
            self._send_json(404, {"error": "not found", "path": path})
            return

        try:
            payload = self._read_json()
            raw_name = payload.get("name", "")
            if not isinstance(raw_name, str):
                raise ValueError('JSON "name" must be a string')
            name = raw_name.strip()
            raw_body = payload.get("body", "")
            if raw_body is None:
                body = ""
            elif isinstance(raw_body, str):
                body = raw_body
            else:
                raise ValueError('JSON "body" must be a string when provided')
            if not name:
                raise ValueError('JSON must include a non-empty "name"')
            write_note(name, body)
        except ValueError as exc:
            self._send_json(400, {"error": str(exc)})
            return
        except OSError as exc:
            self._send_json(503, {"error": f"could not write note: {exc}"})
            return

        self._send_json(201, {"created": name, "notes": list_notes()})


def main() -> None:
    ensure_data_dir()
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"python-api listening on 0.0.0.0:{PORT}")
    print(f"DATA_DIR={DATA_DIR}")
    print("Try: curl http://127.0.0.1:%s/health" % PORT)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nshutting down")
        server.server_close()


if __name__ == "__main__":
    main()

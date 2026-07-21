# python-api

A tiny HTTP API written in Python's standard library. No frameworks, no
`pip install`. You run it on your machine first; later exercises turn the same
code into an image, attach volumes, run it as non-root, and put it behind
Compose.

That order matters. When something fails in a container, you already know what
"working" looked like outside one.

## What you learn from this app

| Endpoint | Role | Why it exists |
|---|---|---|
| `GET /health` | Liveness | "Is the process up?" Used by container healthchecks later. |
| `GET /ready` | Readiness | "Can it do useful work?" Here that means the data directory is writable. |
| `GET /notes` / `POST /notes` | Real work | Writes files under `DATA_DIR` so volume exercises have something real to keep. |

Health and ready are deliberately separate. A process can be alive while its
disk is read-only. That distinction shows up again in Kubernetes readiness
probes; this app keeps the same idea in plain HTTP.

## Requirements

- Python 3.11 or later (3.14 matches the lab's shared base image series)

## Run it

From this directory:

```bash
python app.py
```

On Windows PowerShell:

```powershell
python app.py
```

Default listen port is **8211** (the lab's reserved port for this app). Override
with environment variables:

```bash
PORT=8211 DATA_DIR=./data python app.py
```

```powershell
$env:PORT = "8211"
$env:DATA_DIR = ".\data"
python app.py
```

## Prove it works

In another terminal:

```bash
curl http://127.0.0.1:8211/health
curl http://127.0.0.1:8211/ready
curl http://127.0.0.1:8211/
curl -X POST http://127.0.0.1:8211/notes \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"hello\",\"body\":\"works on my machine\"}"
curl http://127.0.0.1:8211/notes
```

PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:8211/health
Invoke-RestMethod http://127.0.0.1:8211/ready
Invoke-RestMethod http://127.0.0.1:8211/notes -Method Post `
  -ContentType "application/json" `
  -Body '{"name":"hello","body":"works on my machine"}'
Invoke-RestMethod http://127.0.0.1:8211/notes
```

You should see JSON with `"status": "ok"`, then `"status": "ready"`, then a
created note listed under `notes`. A file appears in `data/hello`.

## Files

| Path | Purpose |
|---|---|
| `app.py` | The whole service |
| `data/` | Created at runtime; gitignored notes live here |

## What comes next in the lab

Later exercises will:

1. Write a Dockerfile for this app and serve `/health` from a container on 8211.
2. Mount a named volume or bind mount over `DATA_DIR` and show that notes survive a recreate.
3. Run the process as uid 10001 and fix the permission fallout on the data directory.

None of that is required to finish this README. Get the native run green first.

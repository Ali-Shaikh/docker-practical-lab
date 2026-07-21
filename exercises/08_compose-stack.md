# Exercise 08: Compose stack (API, Valkey, Postgres)

## The situation

Wire `apps/python-api` together with **Valkey** and **Postgres** using Docker
Compose. Services must wait for dependencies that are actually healthy, not
merely started. Use Compose project name **`dpl`**, lab labels on everything
you create, and publish only on loopback in the **8220-8229** port block.

## What you will learn

- Multi-service Compose files
- `healthcheck` and `depends_on` with `condition: service_healthy`
- Project name, service labels, and loopback port publishing in Compose

## Before you start

```bash
./lab up
docker container rm --force dpl-ex06-api dpl-ex02-api 2>/dev/null || true
```

Use **Valkey**, not Redis. Prefer `valkey/valkey:8-alpine` and
`postgres:17-alpine` (or current alpine series of the same products).

## Steps

### 1. Write a Compose file

Create a Compose file (for example `compose/ex08.yaml` or any path you pass
with `-f`) that declares project name **`dpl`** and three services:

| Service | Role | Notes |
|---|---|---|
| `api` | build from `apps/python-api` | `PORT=8211`, publish **127.0.0.1:8221:8211** |
| `valkey` | cache / broker stand-in | no host publish required |
| `postgres` | SQL database | set `POSTGRES_PASSWORD` (lab-only value is fine) |

Requirements:

- Top-level `name: dpl` (or always pass `-p dpl`)
- Every service has label `cloudsprocket.lab=docker`
- Networks and named volumes you create also carry that label
- Each service has a `healthcheck`
- `api` uses `depends_on` with `condition: service_healthy` for both
  `valkey` and `postgres`
- Host ports only on `127.0.0.1`, inside **8220-8229** (API on **8221**)

Suggested healthchecks:

- API: `curl` or `python` hitting `http://127.0.0.1:8211/health` inside the
  container (install curl in the image, or use a Python one-liner)
- Valkey: `valkey-cli ping`
- Postgres: `pg_isready -U postgres`

### 2. Build and start

From the repository root, with your Compose file path:

```bash
docker compose -f compose/ex08.yaml up -d --build
```

If you omitted `name: dpl`, add `-p dpl`.

### 3. Prove it

```bash
docker compose -f compose/ex08.yaml ps
curl -sS http://127.0.0.1:8221/health
./lab check 08
```

## Check your work

- Compose project `dpl` has running `api`, `valkey` and `postgres` services
- containers carry `cloudsprocket.lab=docker`
- API published on **127.0.0.1:8221** and `/health` succeeds
- dependency services report healthy status

## Clean up

```bash
docker compose -f compose/ex08.yaml down --volumes
```

Use the same `-f` / `-p` flags you used to start the stack.

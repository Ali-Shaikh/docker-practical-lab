# Exercise 10: capstone stack

## The situation

Bring the track together. Compose a small stack that serves **`apps/static-site`**
with nginx and runs **`apps/python-api`** as non-root, with healthchecks and lab
labels throughout. Publish the site on loopback port **8230**.

## What you will learn

- Combining earlier skills in one Compose project
- Non-root API, labelled resources, healthchecks
- A minimal multi-service front-and-API layout

## Before you start

```bash
./lab up
# free ports and earlier compose projects if they collide
docker compose -p dpl down --volumes 2>/dev/null || true
```

## Steps

### 1. Dockerfiles

**API** (reuse exercise 06 ideas): non-root **uid 10001**, `LABEL
cloudsprocket.lab=docker`, `PORT=8211`, writable `DATA_DIR=/data`, healthcheck-
friendly `/health`.

**Static site**: nginx alpine image, copy `apps/static-site` content into the
html root, `LABEL cloudsprocket.lab=docker`. A multi-stage build is optional
here; keep the final image small and free of build tools if you add any.

### 2. Compose file

Create a Compose file (for example `compose/ex10.yaml`) with:

- Project name `dpl-capstone` (via `name:` or `-p dpl-capstone`)
- Service `web`: nginx static site, publish **127.0.0.1:8230:80**
- Service `api`: python-api non-root image, publish **127.0.0.1:8231:8211**
  (or leave API internal-only if your check path only needs the site; the lab
  check expects the API on **8231** as well)
- Labels `cloudsprocket.lab=docker` on services (and volumes/networks you own)
- `healthcheck` on both services
- `web` may `depends_on` `api` with `condition: service_healthy` if you want a
  strict start order (optional)

### 3. Up and verify

```bash
docker compose -f compose/ex10.yaml up -d --build
curl -sS http://127.0.0.1:8230/ | head
curl -sS http://127.0.0.1:8231/health
./lab check 10
```

## Check your work

- project `dpl-capstone` is up with labelled `web` and `api` services
- static site answers on **127.0.0.1:8230** (HTML from the sample site)
- API answers `/health` on **127.0.0.1:8231** and runs as non-root **10001**
- both services report healthy (or at least running with successful HTTP)

## Clean up

```bash
docker compose -f compose/ex10.yaml down --volumes
```

# Exercise 06: non-root and volume permissions

## The situation

Running as root inside a container is a bad habit. Rebuild `apps/python-api` so
the process runs as **uid 10001**, mount a named volume for `DATA_DIR`, and make
sure notes still write successfully. Named volumes often surface permission
fallout the moment you drop root.

## What you will learn

- `USER` in a Dockerfile (numeric uid is fine)
- Creating a system user and `chown` of the data directory
- Why an empty volume can block a non-root process from writing

## Before you start

```bash
./lab up
# free port 8211 if exercises 02 or 05 still hold it
docker container rm --force dpl-ex02-api dpl-ex05-api 2>/dev/null || true
```

## Steps

### 1. Write a non-root Dockerfile

Create `apps/python-api/Dockerfile` (or a second Dockerfile you build with `-f`)
that:

- Starts from `python:3.14-slim` (see `config/images.env`)
- Adds `LABEL cloudsprocket.lab=docker`
- Sets `ENV PORT=8211` and `ENV DATA_DIR=/data`
- Creates user **10001** (and a matching group if you like)
- Ensures `/data` is owned by that user before the process starts
- Ends with `USER 10001` (or `USER 10001:10001`)
- `EXPOSE 8211` and runs `python app.py`

Hint: if the named volume is empty on first mount, Docker seeds it from the
image mountpoint, including ownership. `chown` in the image matters.

### 2. Build

```bash
docker build -t dpl-python-api:ex06 apps/python-api
```

### 3. Volume and run

```bash
docker volume create \
  --label cloudsprocket.lab=docker \
  dpl-ex06-data

# Git Bash on Windows: keep MSYS_NO_PATHCONV=1 for -v mounts.
MSYS_NO_PATHCONV=1 docker run -d \
  --name dpl-ex06-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  -e DATA_DIR=/data \
  -v dpl-ex06-data:/data \
  dpl-python-api:ex06
```

### 4. Prove non-root writes work

```bash
curl -sS http://127.0.0.1:8211/ready
curl -sS -X POST http://127.0.0.1:8211/notes \
  -H "Content-Type: application/json" \
  --data-binary "{\"name\":\"nonroot\",\"body\":\"uid 10001 can write\"}"
curl -sS http://127.0.0.1:8211/notes
./lab check 06
```

If `/ready` returns not ready, inspect ownership of `/data` inside the container
and fix the image or the volume mount, then recreate.

## Check your work

- image `dpl-python-api:ex06` exists and is labelled
- container `dpl-ex06-api` runs as user `10001` (or `10001:10001`)
- loopback publish of **8211**, lab label present
- volume `dpl-ex06-data` labelled and mounted at `/data`
- `/ready` succeeds and a note write works

## Clean up

```bash
docker container rm --force dpl-ex06-api
docker volume rm dpl-ex06-data
```

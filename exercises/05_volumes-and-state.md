# Exercise 05: volumes and state

## The situation

Containers are disposable. Data is not. Point `apps/python-api` at a **named
volume** for `DATA_DIR`, write a note through the API, recreate the container,
and prove the note is still there.

## What you will learn

- Named volumes vs the container filesystem
- Mounting a volume at the app data path
- Why recreate does not have to mean data loss

## Before you start

You need a working `dpl-python-api:ex02` image (exercise 02). Free port 8211 if
another exercise container is still bound to it.

## Steps

### 1. Create a labelled named volume

```bash
docker volume create \
  --label cloudsprocket.lab=docker \
  dpl-ex05-data
```

### 2. Run the API with the volume mounted

```bash
# If you use Git Bash on Windows, keep MSYS_NO_PATHCONV=1 so the volume
# mount is not rewritten into a Windows path.
MSYS_NO_PATHCONV=1 docker run -d \
  --name dpl-ex05-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  -e DATA_DIR=/data \
  -v dpl-ex05-data:/data \
  dpl-python-api:ex02
```

### 3. Write a canary note

```bash
curl -sS -X POST http://127.0.0.1:8211/notes \
  -H "Content-Type: application/json" \
  --data-binary "{\"name\":\"canary\",\"body\":\"survives recreate\"}"
curl -sS http://127.0.0.1:8211/notes
```

On PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:8211/notes -Method Post `
  -ContentType "application/json" `
  -Body '{"name":"canary","body":"survives recreate"}'
```

### 4. Recreate the container (same volume)

```bash
docker container rm --force dpl-ex05-api

MSYS_NO_PATHCONV=1 docker run -d \
  --name dpl-ex05-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  -e DATA_DIR=/data \
  -v dpl-ex05-data:/data \
  dpl-python-api:ex02
```

### 5. Confirm the note survived

```bash
curl -sS http://127.0.0.1:8211/notes
./lab check 05
```

## Check your work

- volume `dpl-ex05-data` exists and is labelled
- container mounts that volume at `/data`
- `GET /notes` still lists `canary` after recreate

## Clean up

```bash
docker container rm --force dpl-ex05-api
docker volume rm dpl-ex05-data
```

## Stretch (optional, not checked)

Try the same flow with a **bind mount** to a host directory. Notice permission
and path differences; exercise 06 will dig into non-root and volume ownership.

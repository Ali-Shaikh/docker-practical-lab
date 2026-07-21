# Exercise 04: tag, push and pull from a local registry

## The situation

You built `dpl-python-api:ex02` (exercise 02). Real teams rarely run only from
local tags forever. Practise tagging, pushing and pulling through a **local**
registry on loopback, then run a container from the pulled tag.

## What you will learn

- Image names, tags and repositories
- Starting the lab registry (`./lab registry start`)
- Push and pull over `127.0.0.1:8200`
- Running a container from a registry tag

## Before you start

Complete exercise 02 so image `dpl-python-api:ex02` exists, or rebuild it.

```bash
./lab up
./lab registry start
```

`registry start` runs `registry:3` as `dpl-registry` on `127.0.0.1:8200` with
the lab label.

## Steps

### 1. Tag for the local registry

```bash
docker tag dpl-python-api:ex02 127.0.0.1:8200/dpl-python-api:ex04
```

### 2. Push

```bash
docker push 127.0.0.1:8200/dpl-python-api:ex04
```

Docker Desktop and modern Engine allow HTTP to `127.0.0.1` registries for local
work. If push fails with an HTTPS error, confirm the registry is running:
`./lab status`.

### 3. Remove the local tag (optional proof) and pull again

```bash
docker image rm 127.0.0.1:8200/dpl-python-api:ex04
docker pull 127.0.0.1:8200/dpl-python-api:ex04
```

### 4. Run from the pulled image

```bash
docker run -d \
  --name dpl-ex04-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  127.0.0.1:8200/dpl-python-api:ex04
```

If port 8211 is busy from exercise 02, remove that container first.

### 5. Check

```bash
curl -sS http://127.0.0.1:8211/health
./lab check 04
```

## Check your work

- registry container `dpl-registry` is running and labelled
- catalog or manifest for `dpl-python-api` is present on the registry
- `dpl-ex04-api` serves `/health` from the registry image

## Clean up

```bash
docker container rm --force dpl-ex04-api
./lab registry stop
```

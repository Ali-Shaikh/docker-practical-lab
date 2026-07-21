# Exercise 07: user-defined networks

## The situation

Not every service should see every other service. Create two user-defined
networks: a **front** network and a **back** network. Put the API on both. Put
a small database (Valkey) **only** on the back network under the name `db`.
Prove the API can reach `db` by name, and that a client attached only to the
front network cannot.

## What you will learn

- User-defined bridge networks and DNS names
- Attaching one container to multiple networks
- Network isolation as a basic security control

## Before you start

```bash
./lab up
```

You need a working API image (`dpl-python-api:ex02` or `dpl-python-api:ex06`).

## Steps

### 1. Create labelled networks

```bash
docker network create \
  --label cloudsprocket.lab=docker \
  dpl-ex07-front

docker network create \
  --label cloudsprocket.lab=docker \
  dpl-ex07-back
```

### 2. Start Valkey only on the back network

Use the official Valkey image (not Redis). Give the container a stable name and
a network alias **`db`** so other containers resolve `db` on the back network.

```bash
docker run -d \
  --name dpl-ex07-db \
  --label cloudsprocket.lab=docker \
  --network dpl-ex07-back \
  --network-alias db \
  valkey/valkey:8-alpine
```

Do **not** attach this container to `dpl-ex07-front`. Do not publish the Valkey
port on the host unless you need it for debugging (not required for the check).

### 3. Start the API on both networks

```bash
docker run -d \
  --name dpl-ex07-api \
  --label cloudsprocket.lab=docker \
  --network dpl-ex07-back \
  -p 127.0.0.1:8213:8211 \
  dpl-python-api:ex06
```

If you only have `dpl-python-api:ex02`, that image is fine for this exercise.

Connect the API to the front network as well:

```bash
docker network connect dpl-ex07-front dpl-ex07-api
```

### 4. Prove reachability and isolation

From the API container, `db` should resolve and accept a TCP connection on
port 6379 (Valkey default):

```bash
docker exec dpl-ex07-api python -c \
  "import socket; s=socket.create_connection(('db', 6379), 3); s.close(); print('api->db ok')"
```

From a one-shot client that is **only** on the front network, the same name
must not be reachable:

```bash
docker run --rm \
  --label cloudsprocket.lab=docker \
  --network dpl-ex07-front \
  python:3.14-slim \
  python -c "import socket; socket.create_connection(('db', 6379), 3)"
```

That command should fail (name resolution or connection error). Then:

```bash
./lab check 07
```

## Check your work

- networks `dpl-ex07-front` and `dpl-ex07-back` exist and carry the lab label
- `dpl-ex07-db` is on the back network only, with alias or name usable as `db`
- `dpl-ex07-api` is attached to **both** networks and is labelled
- API can open TCP to `db:6379`; a front-only client cannot

## Clean up

```bash
docker container rm --force dpl-ex07-api dpl-ex07-db
docker network rm dpl-ex07-front dpl-ex07-back
```

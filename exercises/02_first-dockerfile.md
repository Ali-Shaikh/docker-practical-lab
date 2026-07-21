# Exercise 02: your first Dockerfile

## The situation

`apps/python-api` already runs on your machine (`python app.py`). Now package
that same app as an image and run it as a container. When the exercise is done,
`/health` answers from Docker on port **8211**.

## What you will learn

- How a Dockerfile describes an image
- `COPY`, `WORKDIR`, `EXPOSE`, `CMD` and a lab `LABEL`
- Building an image and running a container from your own build

## Before you start

```bash
./lab up
cd apps/python-api
python app.py
# other terminal: curl http://127.0.0.1:8211/health
# stop the native process before you free the port for Docker
```

## Steps

### 1. Write `apps/python-api/Dockerfile`

Requirements:

- Start from the lab Python series image: `python:3.14-slim` (same as
  `config/images.env`)
- Set `WORKDIR` to something sensible (for example `/app`)
- Copy `app.py` into the image
- Set `ENV PORT=8211` and `ENV DATA_DIR=/data`
- Create `/data` and ensure the process can write there for later exercises
- Add `LABEL cloudsprocket.lab=docker`
- `EXPOSE 8211`
- `CMD` that runs `python app.py` (or equivalent)

Keep it simple. No multi-stage build yet; that is exercise 03.

### 2. Build the image

From the repository root (or with the correct context path):

```bash
docker build -t dpl-python-api:ex02 apps/python-api
```

### 3. Run a container from your image

```bash
docker run -d \
  --name dpl-ex02-api \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8211:8211 \
  dpl-python-api:ex02
```

### 4. Prove it

```bash
curl -sS http://127.0.0.1:8211/health
curl -sS http://127.0.0.1:8211/ready
./lab check 02
```

## Check your work

`./lab check 02` expects:

- image `dpl-python-api:ex02` exists and is labelled
- container `dpl-ex02-api` is running, labelled, publishing `8211` on loopback
- `/health` and `/ready` succeed

## Clean up (optional)

```bash
docker container rm --force dpl-ex02-api
```

You may keep the image for exercise 04.

## If you get stuck

- Build context wrong: the last argument to `docker build` must be the directory
  that contains the Dockerfile and `app.py`.
- `/ready` fails: ensure `DATA_DIR` is writable inside the container.
- Port busy: stop the native `python app.py` process first.

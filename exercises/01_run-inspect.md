# Exercise 01: run and inspect a container

## The situation

You have a working Docker daemon and a prepared lab network (`./lab up`).
Before you write any Dockerfile, you need a solid mental model: what is an
**image**, what is a **container**, how you **pull**, **run**, **inspect** and
**remove** one safely on this lab.

## What you will learn

- The difference between an image (the package) and a container (a running or stopped instance)
- How to pull an official image and create a container from it
- How to publish a port on `127.0.0.1` only
- Why this lab labels its resources (`cloudsprocket.lab=docker`)
- How to read logs, run a command inside the container, then clean up

## Before you start

```bash
./lab doctor
./lab up
```

On Windows PowerShell: `.\lab.ps1 doctor` and `.\lab.ps1 up`.

The lab pre-pulls base images when you run `up`, including nginx. You will still
practise the pull command so you know how to fetch an image yourself.

## Steps

### 1. Confirm the image is available (or pull it)

```bash
docker image ls nginx:1.30-alpine
docker pull nginx:1.30-alpine
```

An **image** is a packaged filesystem plus metadata. Pulling downloads that
package to your machine. It is not yet a running process.

### 2. Run a container from the image

Create a container named `dpl-ex01-nginx` on the lab network, with the lab
ownership label, publishing host port **8210** only on loopback:

```bash
docker run -d \
  --name dpl-ex01-nginx \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8210:80 \
  nginx:1.30-alpine
```

A **container** is an instance of an image: a process (and its isolated view of
the filesystem) that you can start, stop and remove. The same image can back
many containers.

The label tells the lab that this resource is practice work. `reset` only
removes labelled resources, so your other Docker work is left alone.

### 3. Prove it answers on the host

```bash
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8210/
```

You want `200`. The host port `8210` maps to port `80` inside the container.

### 4. Inspect, logs and exec

```bash
docker container inspect dpl-ex01-nginx --format '{{.State.Status}} {{.Config.Image}}'
docker logs dpl-ex01-nginx
docker exec dpl-ex01-nginx nginx -v
```

You should see a running state, the nginx image name, access logs, and the
nginx version printed from inside the container.

### 5. Check your work (container still running)

```bash
./lab check 01
```

The check looks at the live container: label, loopback port map and HTTP
response. Leave the container running until the check is green.

### 6. Clean up this exercise

```bash
docker container rm --force dpl-ex01-nginx
```

Removing the container does not remove the image. The package stays; the
instance is gone.

## Check your work

Green `./lab check 01` means:

- `dpl-ex01-nginx` is running
- it carries `cloudsprocket.lab=docker`
- it publishes `8210/tcp` on `127.0.0.1`
- `http://127.0.0.1:8210/` returns successfully

Then remove the container as in step 6.

## If you get stuck

- `port is already allocated`: something else holds 8210. Free it or stop the
  other container.
- `network dpl-net not found`: run `./lab up`.
- curl fails but the container runs: confirm the publish flag is
  `127.0.0.1:8210:80` and that the container is still up (`docker ps`).

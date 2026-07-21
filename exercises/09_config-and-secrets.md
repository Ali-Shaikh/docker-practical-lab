# Exercise 09: config and secrets (BuildKit)

## The situation

Secrets that ride in as `ARG`/`ENV` or plain `COPY` often end up in image
history or config. Build image **`dpl-secret-demo:ex09`** so a known secret is
available **only during the build** via a BuildKit secret mount, and is absent
from the finished image metadata and layer history.

## What you will learn

- How secrets leak through `docker history` and image config
- BuildKit `RUN --mount=type=secret,...`
- Keeping a secret out of the final image while still proving the build used it

## Before you start

```bash
./lab up
./lab doctor
```

Doctor should not warn that Buildx is missing. Enable BuildKit if needed
(`DOCKER_BUILDKIT=1`).

## The planted secret

For this exercise the secret material is the literal string:

```text
LAB_LEAKED_SECRET=dpl-ex09-do-not-leak
```

Treat it like a password: it must not remain in the finished image.

### Anti-pattern (do not ship this)

```dockerfile
# BAD: the value is baked into history and often into config
ARG LAB_LEAKED_SECRET
ENV LAB_LEAKED_SECRET=$LAB_LEAKED_SECRET
```

Building with `--build-arg LAB_LEAKED_SECRET=...` makes the leak easy to spot
with `docker history` and `docker image inspect`.

### Preferred pattern

1. Write the secret to a local file that is **not** part of the build context
   (for example under `.local/`, which stays untracked), containing exactly:

   ```text
   LAB_LEAKED_SECRET=dpl-ex09-do-not-leak
   ```

2. In the Dockerfile, consume it only inside a secret mount. **Do not paste the
   secret value into the Dockerfile** (the `RUN` text is stored in image
   history). Check that the mounted file is non-empty and carries the expected
   key name:

   ```dockerfile
   # syntax=docker/dockerfile:1
   FROM python:3.14-slim
   LABEL cloudsprocket.lab=docker
   WORKDIR /app
   RUN --mount=type=secret,id=lab_secret \
       sh -c 'test -s /run/secrets/lab_secret \
         && grep -q "^LAB_LEAKED_SECRET=" /run/secrets/lab_secret \
         && printf "secret-ok\n" > /app/secret-status'
   ```

3. Build with BuildKit:

   ```bash
   DOCKER_BUILDKIT=1 docker build \
     --secret id=lab_secret,src=.local/ex09-secret.txt \
     -t dpl-secret-demo:ex09 \
     -f path/to/Dockerfile \
     path/to/context
   ```

The image should contain a small marker file proving the secret was present at
build time, without storing the secret string itself.

## Check your work

```bash
docker history dpl-secret-demo:ex09
docker image inspect dpl-secret-demo:ex09
./lab check 09
```

The check expects:

- image `dpl-secret-demo:ex09` exists and is labelled
- neither `docker history` nor image `Env` contains `dpl-ex09-do-not-leak`
- a container from the image can read the build-time marker (`secret-ok`)

## Clean up

```bash
docker image rm dpl-secret-demo:ex09
rm -f .local/ex09-secret.txt
```

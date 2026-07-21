# syntax=docker/dockerfile:1
FROM python:3.14-slim

LABEL cloudsprocket.lab=docker

WORKDIR /app

# Consume the secret only during this RUN. Do not embed the secret value in
# the Dockerfile itself (that string would appear in docker history).
RUN --mount=type=secret,id=lab_secret \
    sh -c 'test -s /run/secrets/lab_secret \
      && grep -q "^LAB_LEAKED_SECRET=" /run/secrets/lab_secret \
      && printf "secret-ok\n" > /app/secret-status'

CMD ["cat", "/app/secret-status"]

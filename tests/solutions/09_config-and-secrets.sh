#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SECRET_FILE="${ROOT}/.local/ex09-secret.txt"
CONTEXT_DIR="${ROOT}/tests/solutions/09_config-and-secrets"

mkdir -p "${ROOT}/.local"
printf '%s\n' 'LAB_LEAKED_SECRET=dpl-ex09-do-not-leak' > "${SECRET_FILE}"

docker image rm --force dpl-secret-demo:ex09 >/dev/null 2>&1 || true

DOCKER_BUILDKIT=1 docker build \
  --secret "id=lab_secret,src=${SECRET_FILE}" \
  -t dpl-secret-demo:ex09 \
  -f "${CONTEXT_DIR}/Dockerfile" \
  "${CONTEXT_DIR}" >/dev/null 2>&1

# Sanity: marker present, secret absent from history.
out="$(docker run --rm --label cloudsprocket.lab=docker dpl-secret-demo:ex09)"
[[ "${out}" == *secret-ok* ]] || { echo 'solution 09: marker missing' >&2; exit 1; }

if docker history --no-trunc dpl-secret-demo:ex09 | grep -q 'dpl-ex09-do-not-leak'; then
  echo 'solution 09: secret leaked into history' >&2
  exit 1
fi

exit 0

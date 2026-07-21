#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${ROOT}/tests/solutions/10_capstone/docker-compose.yml"

# Avoid port clashes with earlier exercises where practical.
docker container rm --force dpl-ex06-api dpl-ex02-api >/dev/null 2>&1 || true
docker compose -p dpl -f "${ROOT}/tests/solutions/08_compose-stack/docker-compose.yml" down --volumes >/dev/null 2>&1 || true

docker compose -f "${COMPOSE_FILE}" down --volumes >/dev/null 2>&1 || true
docker compose -f "${COMPOSE_FILE}" up -d --build >/dev/null 2>&1

for _ in $(seq 1 60); do
  web_ok=0
  api_ok=0
  curl -fsS --max-time 2 http://127.0.0.1:8230/ 2>/dev/null | grep -q 'Image versus container' && web_ok=1
  curl -fsS --max-time 2 http://127.0.0.1:8231/health >/dev/null 2>&1 && api_ok=1
  if (( web_ok == 1 && api_ok == 1 )); then
    unhealthy=0
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      health="$(docker container inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}")"
      if [[ "${health}" != 'healthy' ]]; then
        unhealthy=1
        break
      fi
    done < <(docker container ls --quiet --filter 'label=com.docker.compose.project=dpl-capstone')
    if (( unhealthy == 0 )); then
      exit 0
    fi
  fi
  sleep 0.5
done

echo 'solution 10: capstone stack did not become ready' >&2
docker compose -f "${COMPOSE_FILE}" ps >&2 || true
exit 1

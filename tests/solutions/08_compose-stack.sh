#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${ROOT}/tests/solutions/08_compose-stack/docker-compose.yml"

# Free ports / earlier API containers that might collide on images only.
docker container rm --force dpl-ex06-api dpl-ex02-api dpl-ex05-api >/dev/null 2>&1 || true

docker compose -f "${COMPOSE_FILE}" down --volumes >/dev/null 2>&1 || true

docker compose -f "${COMPOSE_FILE}" up -d --build >/dev/null 2>&1

# Wait for API health on published port.
for _ in $(seq 1 60); do
  if curl -fsS --max-time 2 http://127.0.0.1:8221/health >/dev/null 2>&1; then
    # Also wait until compose services report healthy.
    unhealthy=0
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      health="$(docker container inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}")"
      if [[ "${health}" != 'healthy' ]]; then
        unhealthy=1
        break
      fi
    done < <(docker container ls --quiet --filter 'label=com.docker.compose.project=dpl')
    if (( unhealthy == 0 )); then
      exit 0
    fi
  fi
  sleep 0.5
done

echo 'solution 08: compose stack did not become healthy' >&2
docker compose -f "${COMPOSE_FILE}" ps >&2 || true
exit 1

#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly PROJECT='dpl'
readonly HOST_PORT='8221'

require_daemon
printf 'Checking exercise 08 (compose-stack)...\n'

assert_network_ready

# Discover project containers (Compose v2 names: dpl-api-1, or custom container_name).
mapfile -t project_ids < <(
  docker container ls --all --quiet --filter "label=com.docker.compose.project=${PROJECT}" 2>/dev/null || true
)

if (( ${#project_ids[@]} == 0 )); then
  fail_item "no containers found for Compose project '${PROJECT}' (use name: dpl or -p dpl)"
  finish_check '08'
fi

services_found=()
for id in "${project_ids[@]}"; do
  svc="$(docker container inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "${id}" 2>/dev/null || true)"
  running="$(docker container inspect --format '{{.State.Running}}' "${id}" 2>/dev/null || true)"
  lab="$(docker container inspect --format '{{index .Config.Labels "cloudsprocket.lab"}}' "${id}" 2>/dev/null || true)"
  health="$(docker container inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}" 2>/dev/null || true)"

  if [[ "${running}" == 'true' ]]; then
    pass "project ${PROJECT} service '${svc:-unknown}' is running"
  else
    fail_item "project ${PROJECT} service '${svc:-unknown}' is not running"
  fi

  if [[ "${lab}" == 'docker' ]]; then
    pass "service '${svc:-unknown}' carries ${LAB_LABEL}"
  else
    fail_item "service '${svc:-unknown}' must carry label ${LAB_LABEL}"
  fi

  if [[ "${health}" == 'healthy' ]]; then
    pass "service '${svc:-unknown}' is healthy"
  elif [[ "${health}" == 'none' ]]; then
    fail_item "service '${svc:-unknown}' has no healthcheck (configure healthcheck in Compose)"
  else
    fail_item "service '${svc:-unknown}' health status is '${health}', expected healthy"
  fi

  services_found+=("${svc}")
done

for required in api valkey postgres; do
  found=0
  for svc in "${services_found[@]}"; do
    if [[ "${svc}" == "${required}" ]]; then
      found=1
      break
    fi
  done
  if (( found == 1 )); then
    pass "required service '${required}' is present in project ${PROJECT}"
  else
    fail_item "Compose project ${PROJECT} is missing service '${required}'"
  fi
done

# Find the api container and assert loopback publish of 8221.
api_id=''
for id in "${project_ids[@]}"; do
  svc="$(docker container inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "${id}" 2>/dev/null || true)"
  if [[ "${svc}" == 'api' ]]; then
    api_id="${id}"
    break
  fi
done

if [[ -n "${api_id}" ]]; then
  api_name="$(docker container inspect --format '{{.Name}}' "${api_id}" | sed 's#^/##')"
  assert_loopback_port_publish "${api_name}" "${HOST_PORT}"
  assert_http_ok "http://127.0.0.1:${HOST_PORT}/health" '"status"'
else
  fail_item "could not locate the api service container for project ${PROJECT}"
fi

finish_check '08'

#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
# shellcheck source=../tests/lib/check-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/lib/check-common.sh"

readonly PROJECT='dpl-capstone'
readonly WEB_PORT='8230'
readonly API_PORT='8231'

require_daemon
printf 'Checking exercise 10 (capstone)...\n'

assert_network_ready

mapfile -t project_ids < <(
  docker container ls --all --quiet --filter "label=com.docker.compose.project=${PROJECT}" 2>/dev/null || true
)

if (( ${#project_ids[@]} == 0 )); then
  fail_item "no containers found for Compose project '${PROJECT}' (use name: dpl-capstone or -p dpl-capstone)"
  finish_check '10'
fi

services_found=()
api_name=''
web_name=''

for id in "${project_ids[@]}"; do
  svc="$(docker container inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "${id}" 2>/dev/null || true)"
  name="$(docker container inspect --format '{{.Name}}' "${id}" | sed 's#^/##')"
  running="$(docker container inspect --format '{{.State.Running}}' "${id}" 2>/dev/null || true)"
  lab="$(docker container inspect --format '{{index .Config.Labels "cloudsprocket.lab"}}' "${id}" 2>/dev/null || true)"
  user="$(docker container inspect --format '{{.Config.User}}' "${id}" 2>/dev/null || true)"
  health="$(docker container inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}" 2>/dev/null || true)"

  services_found+=("${svc}")
  if [[ "${svc}" == 'api' ]]; then
    api_name="${name}"
  elif [[ "${svc}" == 'web' ]]; then
    web_name="${name}"
  fi

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
    fail_item "service '${svc:-unknown}' has no healthcheck"
  else
    fail_item "service '${svc:-unknown}' health status is '${health}', expected healthy"
  fi

  if [[ "${svc}" == 'api' ]]; then
    if [[ "${user}" == '10001' || "${user}" == '10001:10001' ]]; then
      pass "api runs as non-root user ${user}"
    else
      fail_item "api must run as user 10001 (got '${user}')"
    fi
  fi
done

for required in web api; do
  found=0
  for svc in "${services_found[@]}"; do
    if [[ "${svc}" == "${required}" ]]; then
      found=1
      break
    fi
  done
  if (( found == 1 )); then
    pass "required service '${required}' is present"
  else
    fail_item "Compose project ${PROJECT} is missing service '${required}'"
  fi
done

if [[ -n "${web_name}" ]]; then
  assert_loopback_port_publish "${web_name}" "${WEB_PORT}"
else
  fail_item "could not locate the web service container"
fi

if [[ -n "${api_name}" ]]; then
  assert_loopback_port_publish "${api_name}" "${API_PORT}"
else
  fail_item "could not locate the api service container"
fi

assert_http_ok "http://127.0.0.1:${WEB_PORT}/" 'Image versus container'
assert_http_ok "http://127.0.0.1:${API_PORT}/health" '"status"'
assert_http_ok "http://127.0.0.1:${API_PORT}/ready" 'ready'

finish_check '10'

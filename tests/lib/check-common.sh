#!/usr/bin/env bash
# Shared helpers for exercise checks. Source from checks/*.sh only.
# Behaviour-focused asserts; never print the full solution path.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ROOT
# shellcheck source=../../config/images.env
source "${ROOT}/config/images.env"
readonly LAB_LABEL='cloudsprocket.lab=docker'
readonly NETWORK_NAME='dpl-net'

CHECK_FAILURES=0

pass() {
  printf '  pass  %s\n' "$*"
}

fail_item() {
  printf '  fail  %s\n' "$*" >&2
  CHECK_FAILURES=$((CHECK_FAILURES + 1))
}

require_daemon() {
  docker info >/dev/null 2>&1 \
    || { printf 'Error: Docker daemon is not reachable. Start Docker and run ./lab up.\n' >&2; exit 1; }
}

finish_check() {
  local exercise_id="$1"
  if (( CHECK_FAILURES == 0 )); then
    printf '\nExercise %s: all checks passed.\n' "${exercise_id}"
    exit 0
  fi
  printf '\nExercise %s: %s check(s) failed.\n' "${exercise_id}" "${CHECK_FAILURES}" >&2
  printf 'Re-read the exercise brief, fix the gap, then run ./lab check %s again.\n' "${exercise_id}" >&2
  exit 1
}

assert_network_ready() {
  if docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1 \
    && [[ "$(docker network inspect --format '{{index .Labels "cloudsprocket.lab"}}' "${NETWORK_NAME}" 2>/dev/null || true)" == 'docker' ]]; then
    pass "labelled network ${NETWORK_NAME} exists"
  else
    fail_item "labelled network ${NETWORK_NAME} is missing; run ./lab up"
  fi
}

assert_image_exists() {
  local image="$1"
  if docker image inspect "${image}" >/dev/null 2>&1; then
    pass "image ${image} exists"
  else
    fail_item "image ${image} was not found"
  fi
}

assert_container_running() {
  local name="$1"
  if docker container inspect --format '{{.State.Running}}' "${name}" 2>/dev/null | grep -qx true; then
    pass "container ${name} is running"
  else
    fail_item "container ${name} is not running"
  fi
}

assert_lab_label_on_container() {
  local name="$1"
  local label
  label="$(docker container inspect --format '{{index .Config.Labels "cloudsprocket.lab"}}' "${name}" 2>/dev/null || true)"
  if [[ "${label}" == 'docker' ]]; then
    pass "container ${name} carries ${LAB_LABEL}"
  else
    fail_item "container ${name} must carry label ${LAB_LABEL}"
  fi
}

assert_lab_label_on_image() {
  local image="$1"
  local label
  label="$(docker image inspect --format '{{index .Config.Labels "cloudsprocket.lab"}}' "${image}" 2>/dev/null || true)"
  if [[ "${label}" == 'docker' ]]; then
    pass "image ${image} carries ${LAB_LABEL}"
  else
    fail_item "image ${image} must carry label ${LAB_LABEL} (add LABEL in the Dockerfile)"
  fi
}

assert_loopback_port_publish() {
  local name="$1" host_port="$2"
  local ports
  # HostConfig.PortBindings keys are container ports; host port is HostPort.
  # Example: {"80/tcp":[{"HostIp":"127.0.0.1","HostPort":"8210"}]}
  ports="$(docker container inspect --format '{{json .HostConfig.PortBindings}}' "${name}" 2>/dev/null || true)"
  if [[ "${ports}" == *"\"HostIp\":\"127.0.0.1\""* ]] \
    && [[ "${ports}" == *"\"HostPort\":\"${host_port}\""* ]]; then
    pass "container ${name} publishes ${host_port}/tcp on 127.0.0.1"
  else
    fail_item "container ${name} must publish host port ${host_port} on 127.0.0.1 only"
  fi
}

assert_http_ok() {
  local url="$1" needle="${2:-}"
  local body status
  set +e
  body="$(curl -fsS --max-time 5 "${url}" 2>/dev/null)"
  status=$?
  set -e
  if (( status != 0 )); then
    fail_item "HTTP request failed for ${url}"
    return
  fi
  if [[ -n "${needle}" ]] && [[ "${body}" != *"${needle}"* ]]; then
    fail_item "response from ${url} did not contain expected content"
    return
  fi
  pass "HTTP OK at ${url}"
}

assert_image_size_under() {
  local image="$1" max_bytes="$2"
  local size
  size="$(docker image inspect --format '{{.Size}}' "${image}" 2>/dev/null || echo 0)"
  if [[ "${size}" =~ ^[0-9]+$ ]] && (( size <= max_bytes )); then
    pass "image ${image} size ${size} bytes is under the ceiling ${max_bytes}"
  else
    fail_item "image ${image} is too large (${size} bytes; ceiling ${max_bytes}). Strip build tools from the final stage."
  fi
}

assert_container_user() {
  local name="$1" expected_user="$2"
  local user
  user="$(docker container inspect --format '{{.Config.User}}' "${name}" 2>/dev/null || true)"
  if [[ "${user}" == "${expected_user}" ]]; then
    pass "container ${name} runs as user ${expected_user}"
  else
    fail_item "container ${name} user is '${user}', expected '${expected_user}'"
  fi
}

wait_http() {
  local url="$1" attempts="${2:-40}" i
  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS --max-time 2 "${url}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

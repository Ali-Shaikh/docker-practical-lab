#!/usr/bin/env bash
# Shared helpers for drill break/verify scripts.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ROOT
# shellcheck disable=SC1091
# shellcheck source=../../config/images.env
source "${ROOT}/config/images.env"
readonly LAB_LABEL='cloudsprocket.lab=docker'
readonly NETWORK_NAME='dpl-net'
readonly DRILL_MARKER_VOLUME='dpl-drill-state'
readonly DRILL_MARKER_FILE='active-drill'

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_daemon() {
  docker info >/dev/null 2>&1 || fail 'Docker daemon is not reachable. Start Docker and run ./lab up.'
}

ensure_lab_network() {
  if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    fail "Network ${NETWORK_NAME} is missing. Run ./lab up first."
  fi
}

read_active_drill() {
  if ! docker volume inspect "${DRILL_MARKER_VOLUME}" >/dev/null 2>&1; then
    return 0
  fi
  # Read marker via a short-lived labelled helper container.
  MSYS_NO_PATHCONV=1 docker run --rm \
    --label "${LAB_LABEL}" \
    -v "${DRILL_MARKER_VOLUME}:/state:ro" \
    "${PYTHON_IMAGE}" \
    cat "/state/${DRILL_MARKER_FILE}" 2>/dev/null || true
}

write_active_drill() {
  local slug="$1"
  docker volume create --label "${LAB_LABEL}" "${DRILL_MARKER_VOLUME}" >/dev/null 2>&1 || true
  MSYS_NO_PATHCONV=1 docker run --rm \
    --label "${LAB_LABEL}" \
    -v "${DRILL_MARKER_VOLUME}:/state" \
    "${PYTHON_IMAGE}" \
    sh -c "printf '%s\n' '${slug}' > /state/${DRILL_MARKER_FILE}"
}

clear_active_drill() {
  # Clear only when the named drill is active (or no name was given).
  # Other state files on the marker volume (for example space-hog decoy ids)
  # stay until reset.
  local wanted="${1:-}" active
  active="$(read_active_drill | tr -d '\r\n')"
  if [[ -n "${wanted}" && -n "${active}" && "${active}" != "${wanted}" ]]; then
    return 0
  fi
  if docker volume inspect "${DRILL_MARKER_VOLUME}" >/dev/null 2>&1; then
    MSYS_NO_PATHCONV=1 docker run --rm \
      --label "${LAB_LABEL}" \
      -v "${DRILL_MARKER_VOLUME}:/state" \
      "${PYTHON_IMAGE}" \
      sh -c "rm -f /state/${DRILL_MARKER_FILE}" >/dev/null 2>&1 || true
  fi
}

refuse_if_other_drill_active() {
  local wanted="$1" active
  active="$(read_active_drill | tr -d '\r\n')"
  if [[ -n "${active}" && "${active}" != "${wanted}" ]]; then
    fail "Drill '${active}' is already active. Run ./lab verify ${active} or ./lab reset first."
  fi
}

# Used by verify scripts and the lab wrapper so a repaired older drill cannot
# clear the marker of a different active drill.
refuse_if_mismatched_active_drill() {
  local wanted="$1" active
  active="$(read_active_drill | tr -d '\r\n')"
  if [[ -n "${active}" && "${active}" != "${wanted}" ]]; then
    fail "Drill '${active}' is active. Run: ./lab verify ${active}"
  fi
}

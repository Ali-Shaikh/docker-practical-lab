#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
ensure_lab_network
refuse_if_other_drill_active 'space-hog'

docker container rm --force dpl-drill-space >/dev/null 2>&1 || true

tmpdir="$(mktemp -d)"
# Labelled dangling image (build without a lasting tag).
printf 'FROM %s\nLABEL cloudsprocket.lab=docker\nRUN echo labelled-junk-%s > /junk\n' \
  "${NGINX_IMAGE}" "${RANDOM}${RANDOM}" >"${tmpdir}/Dockerfile"
labelled_dangling="$(docker build -q "${tmpdir}")"

# Stopped labelled container (junk that filter-aware cleanup should remove).
docker run --name dpl-drill-space --label "${LAB_LABEL}" "${NGINX_IMAGE}" true >/dev/null 2>&1 || true

# Unlabelled decoy dangling image that must survive filtered cleanup.
printf 'FROM %s\nRUN echo decoy-%s > /decoy\n' \
  "${NGINX_IMAGE}" "${RANDOM}${RANDOM}" >"${tmpdir}/Dockerfile.decoy"
decoy_id="$(docker build -q -f "${tmpdir}/Dockerfile.decoy" "${tmpdir}")"

docker volume create --label "${LAB_LABEL}" "${DRILL_MARKER_VOLUME}" >/dev/null 2>&1 || true
MSYS_NO_PATHCONV=1 docker run --rm --label "${LAB_LABEL}" \
  -v "${DRILL_MARKER_VOLUME}:/state" "${PYTHON_IMAGE}" \
  sh -c "printf '%s' '${decoy_id}' > /state/space-hog-decoy; printf '%s' '${labelled_dangling}' > /state/space-hog-labelled"

rm -rf "${tmpdir}"
write_active_drill 'space-hog'
printf 'Drill space-hog is active.\n'
printf 'Remove labelled junk (container dpl-drill-space and labelled dangling images).\n'
printf 'Keep unlabelled decoy image %s\n' "${decoy_id}"

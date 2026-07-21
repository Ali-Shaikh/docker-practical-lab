#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/lib/drill-common.sh"

require_daemon
refuse_if_mismatched_active_drill 'space-hog'
failures=0
pass() { printf '  pass  %s\n' "$*"; }
fail_item() { printf '  fail  %s\n' "$*" >&2; failures=$((failures + 1)); }

printf 'Verifying space-hog...\n'

if docker container inspect dpl-drill-space >/dev/null 2>&1; then
  fail_item 'labelled stopped container dpl-drill-space must be removed'
else
  pass 'labelled junk container is gone'
fi

decoy="$(MSYS_NO_PATHCONV=1 docker run --rm --label "${LAB_LABEL}" \
  -v "${DRILL_MARKER_VOLUME}:/state:ro" "${PYTHON_IMAGE}" \
  cat /state/space-hog-decoy 2>/dev/null || true)"
decoy="$(printf '%s' "${decoy}" | tr -d '\r\n')"

if [[ -n "${decoy}" ]] && docker image inspect "${decoy}" >/dev/null 2>&1; then
  pass "unlabelled decoy image ${decoy} survived"
else
  fail_item 'unlabelled decoy dangling image is missing (did you run an unfiltered prune?)'
fi

labelled="$(MSYS_NO_PATHCONV=1 docker run --rm --label "${LAB_LABEL}" \
  -v "${DRILL_MARKER_VOLUME}:/state:ro" "${PYTHON_IMAGE}" \
  cat /state/space-hog-labelled 2>/dev/null || true)"
labelled="$(printf '%s' "${labelled}" | tr -d '\r\n')"
if [[ -n "${labelled}" ]] && docker image inspect "${labelled}" >/dev/null 2>&1; then
  fail_item "labelled dangling image ${labelled} is still present"
else
  pass 'labelled dangling junk image is gone'
fi

if (( failures == 0 )); then
  clear_active_drill 'space-hog'
  printf '\nspace-hog: repaired.\n'
  exit 0
fi
printf '\nspace-hog: still broken (%s check(s) failed).\n' "${failures}" >&2
exit 1

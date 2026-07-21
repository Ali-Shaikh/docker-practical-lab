#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root_dir
readonly image_config="${root_dir}/config/images.env"
readonly lab_label='cloudsprocket.lab=docker'
readonly network_name='dpl-net'
readonly smoke_token="${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}-${BASHPID}"
readonly smoke_prefix="dpl-smoke-${smoke_token}"

readonly down_container_name="${smoke_prefix}-down-container"
readonly down_network_name="${smoke_prefix}-down-network"
readonly down_volume_name="${smoke_prefix}-down-volume"
readonly down_image_ref="${smoke_prefix}-down-image:latest"

readonly reset_container_name="${smoke_prefix}-reset-container"
readonly reset_network_name="${smoke_prefix}-reset-network"
readonly reset_volume_name="${smoke_prefix}-reset-volume"
readonly reset_image_ref="${smoke_prefix}-reset-image:latest"

readonly decoy_container_name="${smoke_prefix}-decoy-container"
readonly decoy_network_name="${smoke_prefix}-decoy-network"
readonly decoy_volume_name="${smoke_prefix}-decoy-volume"
readonly decoy_marker="${smoke_prefix}-volume-canary"

declare -a cleanup_containers=()
declare -a cleanup_networks=()
declare -a cleanup_volumes=()
declare -a cleanup_images=()

fail() {
  printf 'Smoke test failed: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local resource
  set +e

  if ! command -v docker >/dev/null 2>&1; then
    return
  fi

  for resource in "${cleanup_containers[@]}"; do
    docker container rm --force "${resource}" >/dev/null 2>&1 || true
  done
  for resource in "${cleanup_networks[@]}"; do
    docker network rm "${resource}" >/dev/null 2>&1 || true
  done
  for resource in "${cleanup_volumes[@]}"; do
    docker volume rm --force "${resource}" >/dev/null 2>&1 || true
  done
  for resource in "${cleanup_images[@]}"; do
    docker image rm --force "${resource}" >/dev/null 2>&1 || true
  done
}

expect_failure_containing() {
  local expected="$1"
  shift
  local output status

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  (( status != 0 )) || fail "command unexpectedly succeeded: $*"
  [[ "${output}" == *"${expected}"* ]] \
    || fail "command did not report '${expected}': $*"
}

array_contains() {
  local needle="$1"
  shift
  local value
  for value in "$@"; do
    [[ "${value}" == "${needle}" ]] && return 0
  done
  return 1
}

assert_baseline_network() {
  local expected_id="$1" actual_id actual_name actual_labels
  actual_id="$(docker network inspect --format '{{.Id}}' "${network_name}")"
  actual_name="$(docker network inspect --format '{{.Name}}' "${network_name}")"
  actual_labels="$(docker network inspect --format '{{json .Labels}}' "${network_name}")"

  [[ "${actual_id}" == "${expected_id}" ]] \
    || fail "${network_name} changed identity unexpectedly"
  [[ "${actual_name}" == "${network_name}" ]] \
    || fail "the baseline network is not named ${network_name}"
  [[ "${actual_labels}" == '{"cloudsprocket.lab":"docker"}' ]] \
    || fail "${network_name} does not have the exact lab ownership label"
}

assert_no_ownership_label() {
  local kind="$1" reference="$2" actual
  case "${kind}" in
    container)
      actual="$(docker container inspect --format \
        '{{index .Config.Labels "cloudsprocket.lab"}}' "${reference}")"
      ;;
    network)
      actual="$(docker network inspect --format \
        '{{index .Labels "cloudsprocket.lab"}}' "${reference}")"
      ;;
    volume)
      actual="$(docker volume inspect --format \
        '{{index .Labels "cloudsprocket.lab"}}' "${reference}")"
      ;;
    image)
      actual="$(docker image inspect --format \
        '{{index .Config.Labels "cloudsprocket.lab"}}' "${reference}")"
      ;;
    *)
      fail "unsupported resource kind in ownership assertion: ${kind}"
      ;;
  esac

  [[ -z "${actual}" || "${actual}" == '<no value>' ]] \
    || fail "unlabelled ${kind} ${reference} unexpectedly has a lab ownership label"
}

assert_dangling_image() {
  local expected_id="$1" image_id
  while IFS= read -r image_id; do
    [[ "${image_id}" == "${expected_id}" ]] && return 0
  done < <(docker image ls --all --quiet --no-trunc --filter dangling=true)
  fail "image ${expected_id} is no longer dangling"
}

start_container_and_expect_success() {
  local container_id="$1" state='created' exit_code start_status attempt
  for attempt in 1 2 3; do
    set +e
    if command -v timeout >/dev/null 2>&1; then
      timeout 20s docker container start "${container_id}" >/dev/null
    else
      docker container start "${container_id}" >/dev/null
    fi
    start_status=$?
    set -e

    state="$(docker container inspect --format '{{.State.Status}}' "${container_id}")"
    [[ "${state}" != 'created' ]] && break
    printf 'Docker did not complete container start attempt %s; retrying safely.\n' "${attempt}"
  done
  [[ "${state}" != 'created' ]] \
    || fail "container ${container_id} did not start after three attempts"
  if (( start_status != 0 )) && [[ "${state}" != 'running' && "${state}" != 'exited' ]]; then
    fail "container ${container_id} start returned ${start_status} in state ${state}"
  fi

  for _ in {1..60}; do
    state="$(docker container inspect --format '{{.State.Status}}' "${container_id}")"
    if [[ "${state}" == 'exited' ]]; then
      exit_code="$(docker container inspect --format '{{.State.ExitCode}}' "${container_id}")"
      if [[ "${exit_code}" == '0' ]]; then
        return
      fi
      docker container logs "${container_id}" >&2 || true
      fail "container ${container_id} exited with code ${exit_code}"
    fi
    [[ "${state}" == 'running' || "${state}" == 'created' ]] \
      || fail "container ${container_id} entered unexpected state ${state}"
    sleep 0.25
  done
  fail "container ${container_id} did not finish within 15 seconds"
}

make_labelled_image() {
  local image_ref="$1" message="$2"
  tar --create --file=- --files-from=/dev/null |
    docker image import \
      --message "${message}" \
      --change "LABEL ${lab_label}" \
      - "${image_ref}" |
    tr -d '\r\n'
}

make_dangling_image() {
  local message="$1"
  tar --create --file=- --files-from=/dev/null |
    docker image import --message "${message}" - |
    tr -d '\r\n'
}

assert_container_missing() {
  local id="$1"
  if docker container inspect "${id}" >/dev/null 2>&1; then
    fail "old labelled container ${id} survived reset"
  fi
}

assert_network_missing() {
  local id="$1"
  if docker network inspect "${id}" >/dev/null 2>&1; then
    fail "old labelled network ${id} survived reset"
  fi
}

assert_volume_missing() {
  local id="$1"
  if docker volume inspect "${id}" >/dev/null 2>&1; then
    fail "old labelled volume ${id} survived reset"
  fi
}

assert_image_missing() {
  local id="$1"
  if docker image inspect "${id}" >/dev/null 2>&1; then
    fail "old labelled image ${id} survived reset"
  fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cd "${root_dir}"
[[ -f "${image_config}" ]] || fail "image configuration is missing: ${image_config}"
# shellcheck source=config/images.env
source "${image_config}"
: "${NGINX_IMAGE:?NGINX_IMAGE is required}"

baseline_before="$(docker network inspect --format '{{.Id}}' \
  "${network_name}" 2>/dev/null || true)"

printf 'Checking doctor and scaffold command behaviour.\n'
bash ./lab doctor

help_output="$(bash ./lab help)"
for reserved_verb in check break verify drills registry; do
  [[ "${help_output}" == *"${reserved_verb}"* ]] \
    || fail "help does not advertise the ${reserved_verb} command"
done

expect_failure_containing \
  'Exercise 99 is not available in this alpha yet.' \
  bash ./lab check 99
expect_failure_containing \
  'Break/fix drills is reserved by the lab contract but is not available' \
  bash ./lab break smoke-placeholder
expect_failure_containing \
  'Break/fix verification is reserved by the lab contract but is not available' \
  bash ./lab verify smoke-placeholder
drills_output="$(bash ./lab drills)"
[[ "${drills_output}" == *'No drills are available in this alpha yet.'* ]] \
  || fail 'the reserved drills command did not report availability clearly'

printf 'Checking first and repeated startup.\n'
bash ./lab up
first_network_id="$(docker network inspect --format '{{.Id}}' "${network_name}")"
[[ -n "${baseline_before}" ]] || cleanup_networks+=("${first_network_id}")
assert_baseline_network "${first_network_id}"

bash ./lab up
second_network_id="$(docker network inspect --format '{{.Id}}' "${network_name}")"
[[ "${second_network_id}" == "${first_network_id}" ]] \
  || fail 'repeated up replaced the baseline network'
assert_baseline_network "${first_network_id}"

printf 'Checking down preservation.\n'
down_network_id="$(docker network create --label "${lab_label}" "${down_network_name}")"
cleanup_networks+=("${down_network_id}")

down_volume_id="$(docker volume create --label "${lab_label}" "${down_volume_name}")"
cleanup_volumes+=("${down_volume_id}")

down_image_id="$(make_labelled_image \
  "${down_image_ref}" "${smoke_prefix}-down-labelled-image")"
[[ "${down_image_id}" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || fail 'the labelled down-test image did not return a full image ID'
cleanup_images+=("${down_image_id}")

down_container_id="$(MSYS_NO_PATHCONV=1 docker container create \
  --name "${down_container_name}" \
  --label "${lab_label}" \
  --network "${down_network_name}" \
  --mount "type=volume,source=${down_volume_name},target=/dpl-smoke" \
  "${NGINX_IMAGE}")"
cleanup_containers+=("${down_container_id}")

bash ./lab down

if docker container inspect "${down_container_id}" >/dev/null 2>&1; then
  fail 'down left its labelled smoke container behind'
fi
[[ "$(docker network inspect --format '{{.Id}}' "${network_name}")" \
  == "${first_network_id}" ]] || fail 'down replaced or removed the baseline network'
[[ "$(docker network inspect --format '{{.Id}}' "${down_network_name}")" \
  == "${down_network_id}" ]] || fail 'down replaced or removed a labelled test network'
[[ "$(docker volume inspect --format '{{.Name}}' "${down_volume_name}")" \
  == "${down_volume_id}" ]] || fail 'down removed a labelled test volume'
[[ "$(docker image inspect --format '{{.Id}}' "${down_image_id}")" \
  == "${down_image_id}" ]] || fail 'down removed a labelled test image'

printf 'Creating labelled reset targets and unlabelled decoys.\n'
reset_network_id="$(docker network create --label "${lab_label}" "${reset_network_name}")"
cleanup_networks+=("${reset_network_id}")

reset_volume_id="$(docker volume create --label "${lab_label}" "${reset_volume_name}")"
cleanup_volumes+=("${reset_volume_id}")

reset_image_id="$(make_labelled_image \
  "${reset_image_ref}" "${smoke_prefix}-reset-labelled-image")"
[[ "${reset_image_id}" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || fail 'the labelled reset-test image did not return a full image ID'
cleanup_images+=("${reset_image_id}")

reset_container_id="$(MSYS_NO_PATHCONV=1 docker container create \
  --name "${reset_container_name}" \
  --label "${lab_label}" \
  --network "${reset_network_name}" \
  --mount "type=volume,source=${reset_volume_name},target=/dpl-smoke" \
  "${NGINX_IMAGE}")"
cleanup_containers+=("${reset_container_id}")

decoy_network_id="$(docker network create "${decoy_network_name}")"
cleanup_networks+=("${decoy_network_id}")

decoy_volume_id="$(docker volume create "${decoy_volume_name}")"
cleanup_volumes+=("${decoy_volume_id}")
decoy_volume_created_at="$(docker volume inspect --format '{{.CreatedAt}}' \
  "${decoy_volume_name}")"

decoy_container_id="$(MSYS_NO_PATHCONV=1 docker container create \
  --name "${decoy_container_name}" \
  --network "${decoy_network_name}" \
  --mount "type=volume,source=${decoy_volume_name},target=/dpl-smoke" \
  --env "DPL_SMOKE_MARKER=${decoy_marker}" \
  "${NGINX_IMAGE}" \
  sh -c 'if [ -f /dpl-smoke/canary ]; then [ "$(cat /dpl-smoke/canary)" = "$DPL_SMOKE_MARKER" ]; else printf "%s" "$DPL_SMOKE_MARKER" > /dpl-smoke/canary; fi')"
cleanup_containers+=("${decoy_container_id}")
start_container_and_expect_success "${decoy_container_id}"

decoy_image_id="$(make_dangling_image "${smoke_prefix}-decoy-dangling-image")"
[[ "${decoy_image_id}" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || fail 'the unlabelled decoy image did not return a full image ID'
cleanup_images+=("${decoy_image_id}")

assert_no_ownership_label container "${decoy_container_id}"
assert_no_ownership_label network "${decoy_network_id}"
assert_no_ownership_label volume "${decoy_volume_id}"
assert_no_ownership_label image "${decoy_image_id}"
assert_dangling_image "${decoy_image_id}"

mapfile -t old_labelled_container_ids < <(
  docker container ls --all --quiet --no-trunc --filter "label=${lab_label}"
)
mapfile -t old_labelled_network_ids < <(
  docker network ls --quiet --no-trunc --filter "label=${lab_label}"
)
mapfile -t old_labelled_volume_ids < <(
  docker volume ls --quiet --filter "label=${lab_label}"
)
mapfile -t old_labelled_image_ids < <(
  docker image ls --all --quiet --no-trunc --filter "label=${lab_label}"
)

array_contains "${reset_container_id}" "${old_labelled_container_ids[@]}" \
  || fail 'the labelled reset container was not selected by the ownership filter'
array_contains "${first_network_id}" "${old_labelled_network_ids[@]}" \
  || fail 'the baseline network was not selected by the ownership filter'
array_contains "${reset_network_id}" "${old_labelled_network_ids[@]}" \
  || fail 'the labelled reset network was not selected by the ownership filter'
array_contains "${reset_volume_id}" "${old_labelled_volume_ids[@]}" \
  || fail 'the labelled reset volume was not selected by the ownership filter'
array_contains "${reset_image_id}" "${old_labelled_image_ids[@]}" \
  || fail 'the labelled reset image was not selected by the ownership filter'

printf 'Checking label-only reset and resource identity.\n'
bash ./lab reset

new_network_id="$(docker network inspect --format '{{.Id}}' "${network_name}")"
cleanup_networks+=("${new_network_id}")
[[ "${new_network_id}" != "${first_network_id}" ]] \
  || fail 'reset did not replace the baseline network with a new network ID'
assert_baseline_network "${new_network_id}"

for old_id in "${old_labelled_container_ids[@]}"; do
  assert_container_missing "${old_id}"
done
for old_id in "${old_labelled_network_ids[@]}"; do
  assert_network_missing "${old_id}"
done
for old_id in "${old_labelled_volume_ids[@]}"; do
  assert_volume_missing "${old_id}"
done
for old_id in "${old_labelled_image_ids[@]}"; do
  assert_image_missing "${old_id}"
done

mapfile -t current_labelled_container_ids < <(
  docker container ls --all --quiet --no-trunc --filter "label=${lab_label}"
)
mapfile -t current_labelled_network_ids < <(
  docker network ls --quiet --no-trunc --filter "label=${lab_label}"
)
mapfile -t current_labelled_volume_ids < <(
  docker volume ls --quiet --filter "label=${lab_label}"
)
mapfile -t current_labelled_image_ids < <(
  docker image ls --all --quiet --no-trunc --filter "label=${lab_label}"
)

(( ${#current_labelled_container_ids[@]} == 0 )) \
  || fail 'reset recreated a labelled container unexpectedly'
(( ${#current_labelled_network_ids[@]} == 1 )) \
  || fail 'reset did not recreate exactly one labelled network'
[[ "${current_labelled_network_ids[0]}" == "${new_network_id}" ]] \
  || fail 'the only labelled network after reset is not the new dpl-net'
(( ${#current_labelled_volume_ids[@]} == 0 )) \
  || fail 'reset recreated a labelled volume unexpectedly'
(( ${#current_labelled_image_ids[@]} == 0 )) \
  || fail 'reset recreated a labelled image unexpectedly'

[[ "$(docker container inspect --format '{{.Id}}' "${decoy_container_name}")" \
  == "${decoy_container_id}" ]] || fail 'reset changed the unlabelled container ID'
[[ "$(docker network inspect --format '{{.Id}}' "${decoy_network_name}")" \
  == "${decoy_network_id}" ]] || fail 'reset changed the unlabelled network ID'
[[ "$(docker volume inspect --format '{{.Name}}' "${decoy_volume_name}")" \
  == "${decoy_volume_id}" ]] || fail 'reset changed the unlabelled volume identity'
[[ "$(docker volume inspect --format '{{.CreatedAt}}' "${decoy_volume_name}")" \
  == "${decoy_volume_created_at}" ]] || fail 'reset recreated the unlabelled volume'
[[ "$(docker image inspect --format '{{.Id}}' "${decoy_image_id}")" \
  == "${decoy_image_id}" ]] || fail 'reset changed the unlabelled dangling image ID'
assert_dangling_image "${decoy_image_id}"

# Starting the same decoy container again verifies that the volume canary survived.
start_container_and_expect_success "${decoy_container_id}"
[[ "$(docker container inspect --format '{{.Id}}' "${decoy_container_name}")" \
  == "${decoy_container_id}" ]] || fail 'the decoy container identity changed after its canary check'

printf 'Running exercise 01-10 reference solutions and checks.\n'
bash ./lab up
for exercise in 01 02 03 04 05 06 07 08 09 10; do
  printf '  exercise %s...\n' "${exercise}"
  case "${exercise}" in
    01) bash ./tests/solutions/01_run-inspect.sh ;;
    02) bash ./tests/solutions/02_first-dockerfile.sh ;;
    03) bash ./tests/solutions/03_image-diet.sh ;;
    04) bash ./tests/solutions/04_tag-and-registry.sh ;;
    05) bash ./tests/solutions/05_volumes-and-state.sh ;;
    06) bash ./tests/solutions/06_non-root.sh ;;
    07) bash ./tests/solutions/07_networks.sh ;;
    08) bash ./tests/solutions/08_compose-stack.sh ;;
    09) bash ./tests/solutions/09_config-and-secrets.sh ;;
    10) bash ./tests/solutions/10_capstone.sh ;;
  esac
  bash ./lab check "${exercise}"
done

# Leave a clean daemon for subsequent CI jobs where possible.
bash ./lab registry stop >/dev/null 2>&1 || true
docker compose -f ./tests/solutions/08_compose-stack/docker-compose.yml down --volumes >/dev/null 2>&1 || true
docker compose -f ./tests/solutions/10_capstone/docker-compose.yml down --volumes >/dev/null 2>&1 || true
bash ./lab down >/dev/null 2>&1 || true
docker container rm --force \
  dpl-ex01-nginx dpl-ex02-api dpl-ex03-app dpl-ex04-api dpl-ex05-api \
  dpl-ex06-api dpl-ex07-api dpl-ex07-db \
  >/dev/null 2>&1 || true
docker network rm dpl-ex07-front dpl-ex07-back >/dev/null 2>&1 || true

printf 'Docker Practical Lab smoke test passed (scaffold + exercises 01-10).\n'

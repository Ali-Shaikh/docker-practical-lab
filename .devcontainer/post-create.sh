#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root_dir
readonly max_attempts=60

cd "${root_dir}"

docker_ready=false
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if docker info >/dev/null 2>&1; then
    docker_ready=true
    break
  fi
  sleep 1
done

if [[ "${docker_ready}" != "true" ]]; then
  printf 'Docker-in-Docker did not become ready within %s seconds.\n' "${max_attempts}" >&2
  exit 1
fi

bash ./lab doctor

printf '\nCodespaces is ready. Start the lab when you choose with: ./lab up\n'
printf 'The lab was not started automatically, so you control image downloads and usage.\n'

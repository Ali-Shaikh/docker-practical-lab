#!/usr/bin/env python3
"""Validate the scaffold's public structure, isolation, and CI contracts."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REQUIRED_FILES = {
    ".devcontainer/devcontainer.json",
    ".devcontainer/post-create.sh",
    ".github/workflows/ci.yml",
    ".gitattributes",
    ".gitignore",
    "LICENSE",
    "README.md",
    "VERSION",
    "config/images.env",
    "lab",
    "lab.ps1",
    "tests/repository-contract.py",
    "tests/smoke.sh",
}
EXPECTED_IMAGES = {
    "PYTHON_IMAGE": "python:3.14-slim",
    "NODE_IMAGE": "node:24-alpine",
    "NGINX_IMAGE": "nginx:1.30-alpine",
    "REGISTRY_IMAGE": "registry:3",
}
SEMVER = re.compile(
    r"(?:0|[1-9][0-9]*)\."
    r"(?:0|[1-9][0-9]*)\."
    r"(?:0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Repository contract check failed: {message}")


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


missing = sorted(path for path in REQUIRED_FILES if not (ROOT / path).is_file())
require(not missing, f"required files are missing: {', '.join(missing)}")

version = read("VERSION").strip()
require(bool(SEMVER.fullmatch(version)), f"VERSION is not semantic versioning: {version!r}")

images: dict[str, str] = {}
for line in read("config/images.env").splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    require(
        bool(re.fullmatch(r"[A-Z][A-Z0-9_]*=[^\s]+", stripped)),
        f"invalid image configuration line: {line!r}",
    )
    key, value = stripped.split("=", maxsplit=1)
    require(key not in images, f"duplicate image setting: {key}")
    images[key] = value
require(images == EXPECTED_IMAGES, "config/images.env has unexpected image series")

devcontainer = json.loads(read(".devcontainer/devcontainer.json"))
require(
    devcontainer.get("image") == "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
    "the development container must use the Ubuntu 24.04 base",
)
features = devcontainer.get("features", {})
dind_features = [
    name
    for name in features
    if name.startswith("ghcr.io/devcontainers/features/docker-in-docker:")
]
require(len(dind_features) == 1, "exactly one Docker-in-Docker feature is required")
require(
    set(features) == {"ghcr.io/devcontainers/features/docker-in-docker:4"},
    "the current Docker-in-Docker feature must be the only development container feature",
)
require(
    features[dind_features[0]].get("dockerDashComposeVersion") == "latest",
    "the Docker Compose plugin must track its current release",
)
require(
    not any("docker-outside-of-docker" in name for name in features),
    "Docker-outside-of-Docker would expose the host daemon",
)
require(
    devcontainer.get("postCreateCommand") == "bash .devcontainer/post-create.sh",
    "postCreateCommand must run the checked-in readiness script",
)
require("mounts" not in devcontainer, "development container mounts must not be declared")
require("workspaceMount" not in devcontainer, "a host workspace mount must not be overridden")

devcontainer_text = read(".devcontainer/devcontainer.json")
for forbidden in (
    "/var/run/docker.sock",
    "/run/docker.sock",
    "docker-outside-of-docker",
    '"workspaceMount"',
):
    require(
        forbidden not in devcontainer_text,
        f"forbidden development container setting: {forbidden}",
    )

run_args = devcontainer.get("runArgs", [])
require(isinstance(run_args, list), "runArgs must be a list when present")
require(
    not any(
        argument == "-v"
        or argument.startswith("--mount")
        or argument.startswith("--volume")
        for argument in run_args
    ),
    "runArgs must not add host mounts",
)

post_create = read(".devcontainer/post-create.sh")
require("docker info" in post_create, "post-create must wait for the Docker daemon")
require("bash ./lab doctor" in post_create, "post-create must run the lab doctor")
require(
    not re.search(r"(?:^|\s)(?:bash\s+)?\./lab\s+up(?:\s|$)", post_create, re.MULTILINE),
    "post-create must not start the lab",
)

wrapper = read("lab")
require("cloudsprocket.lab=docker" in wrapper, "the Bash wrapper is missing its ownership label")
require("dpl-net" in wrapper, "the Bash wrapper is missing its reserved network name")
require(
    "readonly port_min=8200" in wrapper and "readonly port_max=8299" in wrapper,
    "the Bash wrapper is missing its reserved port block",
)
for unsafe_command in (
    "docker system prune",
    "docker builder prune",
    "docker container prune",
    "docker image prune",
    "docker network prune",
    "docker volume prune",
):
    require(
        unsafe_command not in wrapper,
        f"the Bash wrapper contains unsafe cleanup: {unsafe_command}",
    )

workflow = read(".github/workflows/ci.yml")
required_workflow_fragments = (
    "permissions:\n  contents: read",
    "actions/checkout@v7",
    "lycheeverse/lychee-action@v2.9.0",
    "devcontainers/ci@v0.3",
    "ubuntu-24.04-arm",
    "shellcheck -x ./lab",
    "PSScriptAnalyzer",
    "tests/repository-contract.py",
    "tests/smoke.sh",
)
for fragment in required_workflow_fragments:
    require(fragment in workflow, f"CI is missing required contract: {fragment}")
require(
    not re.search(r"^\s{4}container:\s*", workflow, re.MULTILINE),
    "CI jobs must use Docker directly on their runner, not a job container",
)

print("Repository contract check passed.")

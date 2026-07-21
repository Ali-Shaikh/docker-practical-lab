# Docker Practical Lab

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/Ali-Shaikh/docker-practical-lab?quickstart=1)

A practical Docker workspace you clone and keep. It is being built as a free,
MIT-licensed alternative to short-lived hosted playgrounds, with self-checked
exercises and realistic break/fix drills.

This repository is an early alpha. The safe baseline, sample apps under `apps/`,
self-checked exercises **01-10**, and six break/fix drills are ready.

## Quick start

Docker Engine or Docker Desktop must be running. The Docker Compose plugin must
be version 2.20 or later, including the current 5.x series.

On Linux, macOS, WSL or Git Bash:

```bash
./lab doctor
./lab up
./lab status
```

On Windows PowerShell:

```powershell
.\lab.ps1 doctor
.\lab.ps1 up
.\lab.ps1 status
```

`up` creates the labelled `dpl-net` network and downloads the shared official
base images when they are not already present. Once those images are available,
the scaffold works offline.

## Sample apps (run these first)

Before any Dockerfile, run the sample apps on your machine. Each README is the
source of truth for "works on my machine".

| App | Path | Default port |
|---|---|---|
| Python API | [`apps/python-api`](apps/python-api) | 8211 |
| Node app | [`apps/node-app`](apps/node-app) | 8212 |
| Static site | [`apps/static-site`](apps/static-site) | 8080 (native static server) |

See [`apps/README.md`](apps/README.md) for a one-page overview.

## Safety model

The learner's Docker daemon is the workspace. Every container, network, volume
and image created by the lab itself carries `cloudsprocket.lab=docker`.
Lifecycle commands select resources by that label only.

`reset` removes old labelled resources, leaves unlabelled resources untouched,
and recreates a clean `dpl-net`. It deliberately keeps official upstream images
and BuildKit cache because they are shared dependencies and cannot carry the lab
label. The project never runs a broad Docker prune.

Every published lab port is reserved within 8200-8299 and binds to
`127.0.0.1`. Codespaces uses Docker-in-Docker, which isolates its daemon from
your local Docker daemon. The privileged development container is not a
security boundary, and the project does not mount your Docker socket, home
directory or SSH keys.

## Commands

| Command | Purpose |
|---|---|
| `up` | Prepare the labelled network and shared base images |
| `down` | Stop and remove labelled containers while keeping images and volumes |
| `reset` | Remove old labelled resources and recreate the clean baseline |
| `status` | Show labelled containers, ports, registry state and image sizes |
| `doctor` | Check Docker, Compose, BuildKit, disk, ports and stale state |
| `check NN` | Run an exercise self-check (01-10 available) |
| `registry start\|stop` | Local registry on 127.0.0.1:8200 for exercise 04 |
| `break NAME` | Apply a break/fix drill from `drills/` |
| `verify [NAME]` | Verify a repair, or report that nothing is broken |
| `drills` | List available drills |
| `logs [container]` | Follow logs from a labelled lab container |
| `version` | Print the lab version |

## Learning track

| Status | Content |
|---|---|
| Ready | Sample apps under `apps/` |
| Ready | Exercises 01-10 in `exercises/` with `./lab check NN` |
| Ready | Six break/fix drills in `drills/` (`./lab drills`) |

Start with exercise 01 after `./lab up`:

```bash
./lab up
# follow exercises/01_run-inspect.md
./lab check 01
```

After the exercise track, try a drill:

```bash
./lab drills
./lab break crash-loop
# follow drills/crash-loop/brief.md
./lab verify crash-loop
```

Exercise briefs use the same three headings throughout: The situation, What you
will learn, and Check your work.

## Requirements and cost

- Docker Engine or Docker Desktop with a reachable Linux container daemon
- Docker Compose plugin 2.20 or later
- At least 5 GiB free for the complete image-heavy learning track
- A two-core, 8 GB machine for the finished lab

The lab is free. Personal GitHub accounts currently include 120 Codespaces
core-hours and 15 GB storage each month. That is about 60 hours on the default
two-core machine. Stop the Codespace when you finish a session.

## Affiliation

Docker is a trademark of Docker, Inc. This project is not affiliated with or
endorsed by Docker, Inc.

## Licence

[MIT](LICENSE)

# Exercises

Self-checked learning track. Each brief uses the same three headings:
**The situation**, **What you will learn**, and **Check your work**.

| ID | File | Focus |
|---|---|---|
| 01 | [01_run-inspect.md](01_run-inspect.md) | Image vs container, pull, run, ports, logs, exec |
| 02 | [02_first-dockerfile.md](02_first-dockerfile.md) | First Dockerfile for `apps/python-api` |
| 03 | [03_image-diet.md](03_image-diet.md) | Multi-stage build for `apps/node-app` |
| 04 | [04_tag-and-registry.md](04_tag-and-registry.md) | Tag, push, pull via local registry |
| 05 | [05_volumes-and-state.md](05_volumes-and-state.md) | Named volumes and surviving recreate |
| 06 | [06_non-root.md](06_non-root.md) | Non-root uid 10001 and volume permissions |
| 07 | [07_networks.md](07_networks.md) | Front/back networks and service isolation |
| 08 | [08_compose-stack.md](08_compose-stack.md) | Compose with API, Valkey and Postgres |
| 09 | [09_config-and-secrets.md](09_config-and-secrets.md) | BuildKit secrets vs history leaks |
| 10 | [10_capstone.md](10_capstone.md) | Static site + API capstone stack |

Run a check after you finish an exercise:

```bash
./lab check 01
```

Checks never print the full solution. They only report what is still wrong.

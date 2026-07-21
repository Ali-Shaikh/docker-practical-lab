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

Run a check after you finish an exercise:

```bash
./lab check 01
```

Checks never print the full solution. They only report what is still wrong.

Exercises 06-10 (non-root, networks, Compose, secrets, capstone) land in a
later alpha.

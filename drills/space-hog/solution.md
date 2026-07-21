# Solution: space-hog (spoiler)

```bash
docker container rm --force dpl-drill-space
# Remove only lab-labelled unused images if any:
docker image prune --force --filter 'label=cloudsprocket.lab=docker'
```

Never run `docker system prune` or unfiltered `docker image prune` without a
label filter while this lab shares your daemon.

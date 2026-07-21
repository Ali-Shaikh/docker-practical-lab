# Solution: perm-wall (spoiler)

```bash
MSYS_NO_PATHCONV=1 docker run --rm \
  --label cloudsprocket.lab=docker \
  -v dpl-drill-perm-data:/data \
  python:3.14-slim \
  chown -R 10001:10001 /data

docker restart dpl-drill-perm
```

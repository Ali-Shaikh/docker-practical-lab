# Solution: port-tangle (spoiler)

```bash
docker container rm --force dpl-drill-squatter dpl-drill-port
docker run -d \
  --name dpl-drill-port \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8241:80 \
  nginx:1.30-alpine
```

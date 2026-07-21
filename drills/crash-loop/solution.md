# Solution: crash-loop (spoiler)

The image `CMD` points at a missing module. Rebuild with a correct command:

```bash
# From a fixed Dockerfile using: CMD ["python", "app.py"]
docker build -t dpl-drill-crash:fixed path/to/fixed
docker container rm --force dpl-drill-crash
docker run -d \
  --name dpl-drill-crash \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8240:8211 \
  dpl-drill-crash:fixed
```

Or recreate from the broken image with an override:

```bash
docker container rm --force dpl-drill-crash
docker run -d \
  --name dpl-drill-crash \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8240:8211 \
  dpl-drill-crash:broken \
  python app.py
```

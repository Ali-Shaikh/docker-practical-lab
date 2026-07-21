# Solution: zombie-deps (spoiler)

Edit `drills/zombie-deps/stack/docker-compose.yml`:

```yaml
services:
  valkey:
    image: valkey/valkey:8-alpine
    labels:
      cloudsprocket.lab: docker
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 2s
      timeout: 2s
      retries: 10
  api:
    image: dpl-python-api:ex02
    labels:
      cloudsprocket.lab: docker
    ports:
      - "127.0.0.1:8244:8211"
    environment:
      PORT: "8211"
      DATA_DIR: /tmp/data
    depends_on:
      valkey:
        condition: service_healthy
```

```bash
docker compose -f drills/zombie-deps/stack/docker-compose.yml up -d
```

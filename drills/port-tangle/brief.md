# Drill: port-tangle

Difficulty: intermediate

## Ticket

Service `dpl-drill-port` should answer on `http://127.0.0.1:8241/`. Right now
either nothing answers, or another container holds the port while the service
is published elsewhere. Free the path and publish **host** port 8241 to
**container** port 80 on loopback only. Remove the squatter container
`dpl-drill-squatter`.

```bash
./lab break port-tangle
./lab verify port-tangle
```

## Hints

<details>
<summary>Hint 1</summary>

```bash
docker ps -a --filter name=dpl-drill
curl -v http://127.0.0.1:8241/ || true
docker port dpl-drill-port 2>/dev/null || true
docker port dpl-drill-squatter 2>/dev/null || true
```

</details>

<details>
<summary>Hint 2</summary>

`-p` is `host:container`. Something else may already hold host port 8241.
Stop or remove the squatter, then recreate `dpl-drill-port` with the correct
publish map.

</details>

<details>
<summary>Hint 3</summary>

```bash
docker container rm --force dpl-drill-squatter dpl-drill-port
docker run -d \
  --name dpl-drill-port \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8241:80 \
  nginx:1.30-alpine
```

</details>

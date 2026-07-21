# Drill: perm-wall

Difficulty: intermediate

## Ticket

`dpl-drill-perm` runs the lab Python API as uid **10001** with data on volume
`dpl-drill-perm-data`. `/ready` fails because the process cannot write the data
directory. Fix ownership or permissions on the volume without running the app
as root.

```bash
./lab break perm-wall
./lab verify perm-wall
```

## Hints

<details>
<summary>Hint 1</summary>

```bash
curl -sS http://127.0.0.1:8243/ready || true
docker inspect dpl-drill-perm --format 'user={{.Config.User}} mounts={{json .Mounts}}'
```

</details>

<details>
<summary>Hint 2</summary>

Host-side `chown` does not always work for Docker volumes. Run a short-lived
helper container that mounts the same volume and fixes ownership as root, then
leave the app running as 10001.

</details>

<details>
<summary>Hint 3</summary>

```bash
MSYS_NO_PATHCONV=1 docker run --rm \
  --label cloudsprocket.lab=docker \
  -v dpl-drill-perm-data:/data \
  python:3.14-slim \
  chown -R 10001:10001 /data
docker restart dpl-drill-perm
```

</details>

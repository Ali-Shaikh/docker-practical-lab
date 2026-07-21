# Drill: net-split

Difficulty: intermediate

## Ticket

`dpl-drill-api` should reach Redis-compatible Valkey at hostname `db` on the
back network. After a change, name resolution or connectivity failed. Restore
service discovery so the API can open TCP to `db:6379`, without attaching the
database to the frontend network.

```bash
./lab break net-split
./lab verify net-split
```

## Hints

<details>
<summary>Hint 1</summary>

```bash
docker network ls --filter label=cloudsprocket.lab=docker
docker inspect dpl-drill-api --format '{{json .NetworkSettings.Networks}}'
docker inspect dpl-drill-db --format '{{json .NetworkSettings.Networks}}'
```

</details>

<details>
<summary>Hint 2</summary>

Containers only resolve each other on networks they share. Connecting the API
to the back network is usually enough. Do not put the database on the front
network.

</details>

<details>
<summary>Hint 3</summary>

```bash
docker network connect dpl-drill-back dpl-drill-api
docker exec dpl-drill-api python -c "import socket; socket.create_connection(('db',6379),3).close()"
```

</details>

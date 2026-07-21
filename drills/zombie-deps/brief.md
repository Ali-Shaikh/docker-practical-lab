# Drill: zombie-deps

Difficulty: intermediate

## Ticket

Compose project `dpl-drill` should start the API only after Valkey is healthy.
Someone removed the healthcheck and weakened `depends_on`. Restore
`service_healthy` behaviour so a fresh `compose up` waits for a healthy
dependency, and `http://127.0.0.1:8244/health` answers.

Compose file path after break:

`drills/zombie-deps/stack/docker-compose.yml`

```bash
./lab break zombie-deps
./lab verify zombie-deps
```

## Hints

<details>
<summary>Hint 1</summary>

```bash
docker compose -f drills/zombie-deps/stack/docker-compose.yml config
docker compose -f drills/zombie-deps/stack/docker-compose.yml ps
```

</details>

<details>
<summary>Hint 2</summary>

Add a Valkey healthcheck (`valkey-cli ping`) and change `depends_on` to use
`condition: service_healthy` for the API.

</details>

<details>
<summary>Hint 3</summary>

After editing the compose file:

```bash
docker compose -f drills/zombie-deps/stack/docker-compose.yml up -d
curl -sS http://127.0.0.1:8244/health
```

</details>

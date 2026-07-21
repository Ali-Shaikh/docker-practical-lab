# Drill: crash-loop

Difficulty: beginner

## Ticket

A labelled lab app container named `dpl-drill-crash` keeps exiting. The image
was built from a small Python service. Restore a stable running container that
answers on `http://127.0.0.1:8240/health` without removing the ownership label
or changing the published port.

Start the drill:

```bash
./lab break crash-loop
```

When you think it is fixed:

```bash
./lab verify crash-loop
```

## Hints

<details>
<summary>Hint 1</summary>

Inspect the container state and recent logs:

```bash
docker ps -a --filter name=dpl-drill-crash
docker logs dpl-drill-crash
docker inspect dpl-drill-crash --format '{{.State.Status}} {{.State.ExitCode}} {{json .Config.Cmd}}'
```

</details>

<details>
<summary>Hint 2</summary>

Exit code and traceback usually point at a missing module or a bad command.
Compare the image command with a working Python module path.

</details>

<details>
<summary>Hint 3</summary>

Rebuild or recreate the container with a correct `CMD` that runs the app module
that exists in the image. Keep the lab label and `127.0.0.1:8240:8211` publish.

</details>

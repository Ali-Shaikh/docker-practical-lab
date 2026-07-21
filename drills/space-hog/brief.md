# Drill: space-hog

Difficulty: beginner

## Ticket

Labelled dangling images and a stopped lab container are wasting space. Clean
**only** lab-owned junk. An unlabelled decoy dangling image must survive; never
run a bare `docker system prune` or unfiltered image prune.

```bash
./lab break space-hog
./lab verify space-hog
```

## Hints

<details>
<summary>Hint 1</summary>

```bash
docker ps -a --filter label=cloudsprocket.lab=docker
docker images -a --filter label=cloudsprocket.lab=docker
docker images -f dangling=true
```

</details>

<details>
<summary>Hint 2</summary>

Remove the stopped labelled container, then prune **with a label filter**:

```bash
docker container rm --force dpl-drill-space
docker image prune --force --filter 'label=cloudsprocket.lab=docker'
```

</details>

<details>
<summary>Hint 3</summary>

If the decoy disappears, you used an unfiltered prune. Recreate the drill with
`./lab break space-hog` after `./lab reset` if you need a clean attempt.

</details>

# Break and fix drills

Six operational tickets. Each drill has:

| File | Purpose |
|---|---|
| `brief.md` | Ticket and ordered hints |
| `break.sh` | Applies the failure (lab-labelled only) |
| `verify.sh` | Non-mutating checks |
| `solution.md` | Spoiler-fenced repair |

```bash
./lab drills
./lab break crash-loop
./lab verify crash-loop
./lab reset   # clears drill state and labelled junk
```

Only one drill may be active at a time. `./lab verify` with no name reports
when nothing is broken.

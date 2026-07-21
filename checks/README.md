# Exercise checks

Scripts named `NN_slug.sh` are run by `./lab check NN`.

They assert learner-visible behaviour only: labels, ports, HTTP, volumes,
registry catalog. They never print full solutions.

Shared helpers live in `tests/lib/check-common.sh`.

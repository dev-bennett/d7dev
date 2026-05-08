# verify

@../CLAUDE.md

Sanity-check SQL run against soundstripe_prod *after* the modified model
is built on `develop_dab` (or `soundstripe_dev`). Used to confirm row
counts, fan-out behavior, and join coverage before activating the
Polytomic sync.

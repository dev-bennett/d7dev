Manage the session checkpoint for the current analytical work (§9):

If "$ARGUMENTS" is "init" or empty:
1. Find the active analysis domain from recent file edits or ask the user
2. Create analysis/<domain>/checkpoint.md using analysis/_templates/checkpoint.md
3. Populate Completed, In Progress, Open Items from current session state
4. Stage the checkpoint file

If "$ARGUMENTS" is "update":
1. Find the existing checkpoint.md in the active analysis directory
2. Update all sections based on current session state
3. Apply the Staleness Rule: if any Open Item untouched for 3+ work phases, raise it

If "$ARGUMENTS" is "review":
1. Read the current checkpoint.md
2. Summarize status: what's done, what's in progress, what's blocked
3. Flag stale Open Items
4. Flag any Pending Decisions that need human input

POST-COMPACTION RULE: After any context compaction, the FIRST action is to read
checkpoint.md and confirm understanding of every item before resuming work.
Do not resume from memory.

---
name: Workflow limit-checker can freeze at 10/10
description: configureWorkflow's "Workflow limit exceeded (10/10)" count can go stale and block all adds, including overwriting existing names.
---

# configureWorkflow limit-checker can freeze (stale 10/10)

Observed (2026-05-30): `configureWorkflow` rejected every call with
`Workflow limit exceeded (10/10)` even though `listWorkflows()` showed only 8
live workflows. Its error listing still named workflows that had already been
removed via `removeWorkflow` — i.e. the count reads a frozen snapshot, not live
state.

**Symptoms / scope of the bug:**
- The stale count ignores `removeWorkflow` (removals succeed in `listWorkflows`
  but don't free a slot for the checker).
- It blocks BOTH adding a brand-new name AND overwriting an existing name
  (overwrite still runs the limit check first).
- Restarting the JS notebook worker (`code_execution restart:true`) does NOT
  clear it — the cache is server-side, beyond the notebook.
- Direct edits to `.replit` are also blocked ("Direct edits to .replit ... not
  allowed"), so you cannot hand-restore a removed workflow either.

**Consequence:** once you `removeWorkflow` to try to free a slot, you may be
unable to re-add it. Net: you can get permanently stuck below your real
workflow count until the platform-side cache refreshes.

**How to apply:**
- Do NOT `removeWorkflow` to "make room" — the slot won't come back via tools.
- To run a long (>2 min) one-off compute when no slot is free and the cap is
  jammed, don't rely on workflows. Make the script CHECKPOINT-RESUMABLE with an
  internal wall-time budget (exit cleanly before the ~115s bash kill, persist
  progress after every batch), then invoke it repeatedly from bash until done.
  This sidesteps both the 2-min bash limit and the broken workflow tooling.

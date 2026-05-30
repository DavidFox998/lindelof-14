---
name: Durable long-running commands in this environment
description: Why detached processes from a bash tool call die, and the supported way to run >120s commands.
---

# Long / durable commands must run as workflows, not detached from a bash call

A command launched in the background from the `bash` tool (`&`, `nohup ... &`,
`setsid ... &`, `disown`) **does not survive past the end of that tool call.**
Each bash tool invocation runs inside its own transient systemd scope
(`/sys/fs/cgroup/user.slice/shell.slice/shellexec-*.scope`). When the tool call
returns, systemd tears the scope down and SIGKILLs every process in it —
including `setsid`-detached children, which stay in the same cgroup even though
they leave the session/process-group.

**Symptom that misled me (2026-05-30):** a detached Lean check appeared at
~5s with RSS ~314MB, then by the next tool call the process was gone, the
completion sentinel was never written, and memory was back to baseline. It
looked exactly like an OOM kill — but `cat /sys/fs/cgroup/<scope>/memory.events`
showed `oom_kill 0`. Not memory: scope teardown.

**Why:** confirmed via `cat /proc/self/cgroup` (per-call `shellexec-*.scope`)
and `memory.events` (zero oom kills). The shell scope's `memory.max` is `max`
(unlimited), so system-wide free RAM is not the binding constraint either.

**How to apply:**
- The `bash` tool has a hard 120000 ms (2 min) ceiling. For anything that may
  exceed ~2 min AND must run to completion, do **not** background it from bash.
- Run it as a **workflow** (`configureWorkflow` with `outputType: "console"`,
  `autoStart: true`), which is supervisor-managed and persists across tool
  calls. Poll results with `getWorkflowStatus({ name })` (state +
  `output`); read the captured stdout there. Remove the one-shot workflow when
  done.
- This is how the heavy Lean elaboration (`lake env lean <file>` on
  `import Mathlib`, several minutes) and the ~2GB olean recovery
  (`fetch-mathlib-oleans.sh`) were actually run to completion here.
- Gotcha when shelling out to kill workflow processes: do **not** put the
  search pattern directly on the bash command line (`pkill -f "<pattern>"`),
  because the running shell's own cmdline contains the pattern and the shell
  SIGTERMs itself (exit 143). Put the pattern inside a script file and run that
  script instead, or target exact PIDs.

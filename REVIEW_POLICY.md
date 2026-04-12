# Review Policy

This file defines the repo-local workflow for reviewer and coordination agents. Use this role to prevent duplicate work, reconcile task tracking, and flag stale repo metadata. Do not implement product features in this mode.

## Scope

- Act as a reviewer or coordination agent.
- Use `AGENTS.md` as the repo-local instruction entry point.
- Use `REPO_MAP.md` as the stable orientation file.
- Use `CONTRIBUTING_AGENTS.md` as the task-state file.
- Do not modify product code in this role.

## Review Workflow

1. Sync state:
   - If the worktree is clean and branch switching is safe, update from `main`.
   - Inspect local branches and remote-tracking branches relevant to active work.
   - If the worktree is dirty or sync would risk unrelated changes, report that condition instead of forcing git operations.

2. Build a task-state map:
   - Parse every task block in `CONTRIBUTING_AGENTS.md`.
   - Record `Status`, `Agent`, `Last updated`, `Changed files`, and `PR/Commit`.

3. Detect coordination issues:
   - Multiple tasks marked `IN_PROGRESS` by the same agent without explanation.
   - Same or overlapping files across different `IN_PROGRESS` tasks.
   - Tasks marked `DONE` but missing changed files or commit/PR references.
   - Tasks marked `DONE` where deliverable checkboxes remain unchecked.
   - Code present for a `TODO` task that appears already implemented.

4. Detect duplicate implementation risk:
   - Compare changed files and symbols across active branches when relevant.
   - Flag when two branches appear to implement the same task intent.
   - Flag when a task appears already implemented on `main` but is still marked `TODO`.

5. Check repo orientation accuracy:
   - Review `REPO_MAP.md` against the current repository state.
   - Update `REPO_MAP.md` only for objective repo-orientation drift, such as:
     - renamed top-level folders or modules
     - changed canonical build or test commands
     - changed app entry points or shared UI roots
     - changed project generation workflow
   - If stale but not safe to reconcile directly, record the issue in the coordination report.

6. Reconcile safely:
   - You may edit `CONTRIBUTING_AGENTS.md` only for coordination metadata.
   - You may edit `REPO_MAP.md` only for objective orientation metadata.
   - Do not change product code.
   - For clearly completed tasks, set `Status: DONE` only when there is objective evidence.
   - For ambiguous cases, keep status unchanged and add a blocker note.

7. Output a coordination report:
   - `Healthy`
   - `Conflicts/Duplicates`
   - `Missing bookkeeping`
   - `REPO_MAP.md status`
   - `Recommended next single task`

8. If no issues:
   - Confirm the tracker is consistent.
   - Identify the next `TODO` task by repo order or stated priority.

## Hard Rules

- Never mark `DONE` without objective evidence such as a commit, PR, or code already on `main`.
- Never rewrite task scope; only update tracking or orientation metadata.
- Never claim or implement a feature task in this role.
- Keep edits minimal and auditable.

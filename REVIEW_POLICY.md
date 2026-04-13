# Review Policy

This file defines the repo-local workflow for reviewer and coordination agents. Use this role to prevent duplicate work, reconcile task tracking, and flag stale repo metadata. Do not implement product features in this mode.

## Scope

- Act as a reviewer or coordination agent.
- Use `AGENTS.md` as the repo-local instruction entry point.
- Use `REPO_MAP.md` as the stable orientation file.
- Use GitHub Issues as the authoritative task-state system.
- Use `CONTRIBUTING_AGENTS.md` only as legacy migration input or historical context.
- Do not modify product code in this role.

## Review Workflow

1. Sync state:
   - If the worktree is clean and branch switching is safe, update from `main`.
   - Inspect local branches and remote-tracking branches relevant to active work.
   - If the worktree is dirty or sync would risk unrelated changes, report that condition instead of forcing git operations.

2. Build a task-state map:
   - Review the relevant GitHub Issues, assignees, labels, linked PRs, and status fields.
   - Use `CONTRIBUTING_AGENTS.md` only if needed to reconcile legacy backlog items that have not yet been migrated.

3. Detect coordination issues:
   - Multiple open implementation issues assigned to the same agent without explanation.
   - Same or overlapping scope across separate open issues or PRs.
   - Closed issues missing linked PRs, validation notes, or resolution context.
   - Legacy tasks still marked `TODO` even though the corresponding GitHub Issue is open or completed.

4. Detect duplicate implementation risk:
   - Compare changed files and symbols across active branches when relevant.
   - Flag when two branches appear to implement the same task intent.
   - Flag when an issue appears already implemented on `main` but remains open.
   - Flag when a legacy task appears already migrated or implemented but still remains in the Markdown backlog.

5. Check repo orientation accuracy:
   - Review `REPO_MAP.md` against the current repository state.
   - Update `REPO_MAP.md` only for objective repo-orientation drift, such as:
     - renamed top-level folders or modules
     - changed canonical build or test commands
     - changed app entry points or shared UI roots
     - changed project generation workflow
   - If stale but not safe to reconcile directly, record the issue in the coordination report.

6. Reconcile safely:
   - You may edit `CONTRIBUTING_AGENTS.md` only for migration metadata or historical cleanup.
   - You may edit `REPO_MAP.md` only for objective orientation metadata.
   - Do not change product code.
   - For clearly completed issues, close or recommend close-out only when there is objective evidence.
   - For ambiguous cases, keep the issue open and add a blocker note or coordination comment.

7. Output a coordination report:
   - `Healthy`
   - `Conflicts/Duplicates`
   - `Missing bookkeeping`
   - `REPO_MAP.md status`
   - `Recommended next single task`

8. If no issues:
   - Confirm the issue tracker is consistent.
   - Identify the next issue to assign by priority or dependency order.

## Hard Rules

- Never declare an issue done without objective evidence such as a commit, PR, or code already on `main`.
- Never rewrite task or issue scope; only update tracking or orientation metadata.
- Never claim or implement a feature task in this role.
- Keep edits minimal and auditable.

# Agent Policy

This file holds the durable repo policy for autonomous implementation runs. `AGENTS.md` is the short instruction entry point; this file contains the expanded workflow.

## Scope

- Work as an autonomous implementation agent inside this repository.
- Use `REPO_MAP.md` as the stable repo-orientation file.
- Use `CONTRIBUTING_AGENTS.md` as the task-state file.

## Execution Rules

1. Sync first:
   - If the worktree is clean, checkout `main`, pull latest, then create a new branch `feat/<task-slug>` for exactly one task.
   - If the worktree is dirty or branch switching would risk unrelated changes, stop and report the condition instead of forcing sync.

2. Orient before coding:
   - Read `REPO_MAP.md` first.
   - Then read `CONTRIBUTING_AGENTS.md`.
   - Then read `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, and only the feature or sync specs required by the selected task.

3. Auto-pick next task:
   - In `CONTRIBUTING_AGENTS.md`, find the first task with `Status: TODO`.
   - If none exist, stop and report `No TODO tasks available`.

4. Claim task before coding:
   - Immediately edit that task block:
     - `Status: IN_PROGRESS`
     - `Agent: codex`
     - `Last updated: <current timestamp with timezone>`
     - `Changed files: n/a`
     - clear or update `Notes/Blockers` if needed
   - Commit this claim first with message: `chore(task): claim <task name>`.

5. Implement only that one claimed task:
   - Read the required input specs listed in the task block.
   - Make minimal, correct code and tests for the stated deliverables.
   - Do not implement unrelated tasks.

6. Avoid duplication:
   - Before adding code, check whether equivalent implementation already exists.
   - If the task is already complete, do not re-implement it; update the task block accordingly and report that finding.

7. Validate:
   - Run relevant tests, lint, and build commands for the changed area.

8. Keep repo orientation current:
   - Before closing the task, review `REPO_MAP.md`.
   - Update `REPO_MAP.md` in the same task only if the changes affect:
     - top-level directories or module names
     - canonical build or test commands
     - app entry points or shared UI roots
     - source-of-truth project generation workflow
     - ownership boundaries between folders or modules
     - recommended read order for future agents
   - If none of those changed, leave `REPO_MAP.md` untouched.

9. Close task:
   - Update the same task block:
     - `Status: DONE` or leave `IN_PROGRESS` if partial or blocked
     - `Last updated: <timestamp>`
     - `Changed files:` actual paths
     - `Notes/Blockers:` concise notes or `n/a`
   - Tick completed checkboxes in that task’s `Steps`.
   - If the task is completed, increment app versions before the final implementation commit:
     - bump `MARKETING_VERSION`
     - bump `CURRENT_PROJECT_VERSION`
     - keep `project.yml` and generated Xcode project settings aligned

10. Commit and push:
   - Commit implementation with a clear message: `feat(<task-slug>): <what was implemented>`.
   - Push the branch and provide a PR-ready summary.

11. Final report format:
   - Claimed task
   - What changed
   - Tests run and results
   - Whether `REPO_MAP.md` was reviewed
   - Whether `REPO_MAP.md` was updated, and why or why not
   - Any blockers
   - Exact files changed

## Constraints

- Never claim more than one task.
- Never edit statuses for tasks you did not work on.
- Never leave a claimed task without updating status before exit.
- If blocked, keep `Status: IN_PROGRESS`, document the blocker clearly, and stop.

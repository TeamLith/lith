# Agent Instructions

This repository uses this file as the default repo-local instruction entry point for autonomous coding agents. Human operators should start with `HUMANS.md`.

## Bootstrap

Follow this order before making changes:

1. Read `REPO_MAP.md`.
2. Read `CONTRIBUTING_AGENTS.md`.
3. Read `README.md`, `ARCHITECTURE.md`, and `DATA_MODEL.md`.
4. Read only the feature or sync specs required by the selected task.

## Role Selection

- For autonomous implementation runs, also follow `AGENT_POLICY.md`.
- For reviewer or coordination runs, also follow `REVIEW_POLICY.md`.
- Reviewer or coordination agents must not implement product features.

## Task Workflow

- Work on exactly one task from `CONTRIBUTING_AGENTS.md`.
- Pick the first task with `Status: TODO`.
- If no TODO task exists, stop and report `No TODO tasks available`.
- Claim the task before coding by marking it `IN_PROGRESS`, setting `Agent: codex`, updating `Last updated`, and using `Changed files: n/a` until real paths are known.
- Do not edit task state for tasks you did not work on.
- Do not implement unrelated tasks.

## Git Workflow

- If the worktree is clean, sync from `main` and create a branch for exactly one task.
- If the worktree is dirty or switching branches would risk unrelated changes, stop and report that condition instead of forcing git operations.
- Keep claim and implementation commits separate when following the task workflow in `AGENT_POLICY.md`.

## Validation

- Run relevant tests and build commands for the changed area before closing the task.
- Prefer the canonical commands listed in `REPO_MAP.md`.

## Repo Map Maintenance

- Review `REPO_MAP.md` before closing every task.
- Update `REPO_MAP.md` only when the task changes durable repo orientation, such as:
  - top-level directories or module names
  - canonical build or test commands
  - app entry points or shared UI roots
  - project generation workflow
  - folder or module ownership boundaries
  - recommended read order for future sessions
- If none of those changed, leave `REPO_MAP.md` untouched.

## Task Close-Out

- Update the claimed task with final status, timestamp, changed files, and concise notes or blockers before exit.
- When a claimed task is completed, increment the app versions before finishing the work:
  - bump `MARKETING_VERSION`
  - bump `CURRENT_PROJECT_VERSION`
  - keep `project.yml` and generated Xcode project settings in sync
- If blocked, leave the task `IN_PROGRESS` and record the blocker clearly.
- Report whether `REPO_MAP.md` was reviewed and whether it was updated.

## Detailed Policy

- Use `AGENT_POLICY.md` for the full autonomous implementation workflow, commit expectations, and final reporting format.
- Use `REVIEW_POLICY.md` for reviewer and coordination workflow, duplicate-work detection, and metadata reconciliation.

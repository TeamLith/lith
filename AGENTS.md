# Agent Instructions

This repository uses this file as the default repo-local instruction entry point for autonomous coding agents. Human operators should start with `HUMANS.md`.

## Bootstrap

Follow this order before making changes:

1. Read `REPO_MAP.md`.
2. Read the selected GitHub Issue, supplied issue body, or task-intake input for the run.
3. Read `README.md`, `ARCHITECTURE.md`, and `DATA_MODEL.md`.
4. Read only the feature or sync specs required by the selected issue or supplied task-intake input.
5. Read `CONTRIBUTING_AGENTS.md` only when migrating legacy tasks or checking archived task history.

## Role Selection

- For autonomous implementation runs, also follow `AGENT_POLICY.md`.
- For reviewer or coordination runs, also follow `REVIEW_POLICY.md`.
- Reviewer or coordination agents must not implement product features.

## Run Modes

- Default implementation run:
  use the GitHub issue flow below and work one issue at a time.
- Task intake run:
  if the user explicitly asks to add new tracked `TODO` items or convert one or more repo `## Task:` blocks into GitHub Issues, do not implement the tasks in that run. Create or prepare one GitHub Issue per task instead.
- Repo self-improvement run:
  if the user explicitly asks for a repo self-improvement run, pass, or audit, do not auto-pick a `TODO`. Follow the dedicated self-improvement workflow in `AGENT_POLICY.md` instead.
- Task intake runs must keep GitHub Issues as the live source of truth. Do not append new active tasks to `CONTRIBUTING_AGENTS.md`.
- Self-improvement runs must stay bounded to repo workflow, contributor workflow, review/handoff process, validation, CI, release process, docs, or repo-local skill guidance. They must not drift into product feature implementation.
- When recommendations or best practices may have changed, use current primary sources instead of relying on static memory.

## Issue Workflow

- Work on exactly one GitHub Issue at a time.
- Prefer an issue explicitly provided by the user or already assigned to you.
- Before coding, make the reservation visible on GitHub.
- If your environment supports GitHub assignment and a human has not pre-assigned work, assign the issue to yourself before coding.
- If assignment is unavailable but issue comments are writable, post a claim comment on the issue before creating a branch or editing files.
- If your environment can do neither, do not auto-pick from an unclaimed backlog in parallel mode; ask for an issue number or human assignment instead.
- Do not implement unrelated work outside the chosen issue.

## Repo Self-Improvement Runs

- Only perform repo-process, workflow, or documentation improvements when that work is either the selected GitHub Issue or an explicitly requested repo self-improvement run.
- Keep these runs bounded to agent instructions, human contribution guidance, task tracking, review/handoff workflow, contribution intake/review guidance, validation workflow, release/process docs, or clearly justified repo-local skill guidance.
- Update existing guidance before inventing new files, parallel docs, or new repo structure.
- Escalate to a human for secrets, signing, legal/license choices, paid services, or one-time setup inputs an agent cannot discover safely.
- Use `AGENT_POLICY.md` for the detailed checklist on meta-improvement runs, skill maintenance, validation, and reporting.

## Task Intake Runs

- Use this run only when the user explicitly asks to add tracked work rather than implement it immediately.
- Accept one or more task blocks in the repo `## Task:` format from `CONTRIBUTING_AGENTS.md`, but keep them in standalone markdown or the user prompt instead of appending new live tasks to that archive file.
- Create one GitHub Issue per task and stop after intake unless the user explicitly asks for implementation in a separate run.
- Prefer direct GitHub issue creation when writes are available. If issue creation is unavailable, generate the issue payload or manifest and report the blocker clearly.
- Use `scripts/migrate_pending_tasks_to_github_issues.py` with a standalone markdown file or stdin for structured imports.
- Creating the issues updates the GitHub Issues tracker; any GitHub Projects routing remains governed by existing human-owned configuration or repo automation.

## Git Workflow

- If the worktree is clean, sync from `main` and create a branch for exactly one issue.
- If the worktree is dirty or switching branches would risk unrelated changes, stop and report that condition instead of forcing git operations.
- Keep claim and implementation commits separate when following the issue workflow in `AGENT_POLICY.md`.

## Validation

- Run relevant tests and build commands for the changed area before closing the task.
- Prefer the canonical commands listed in `REPO_MAP.md`.
- When an issue changes user-facing behavior, onboarding, settings, workflows, or adds a new feature, update the matching page under `Docs/site` in the same issue before close-out. Treat that folder as the source of truth for the GitHub Pages user guide.

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

## Issue Close-Out

- Update the linked GitHub Issue or PR with concise notes, blockers, and validation status when your environment supports it.
- If the completed issue changes shipped user behavior or introduces a new user-facing capability, include the corresponding user-documentation update in the same scope instead of deferring it silently.
- When a claimed issue is completed and it changes shipped app behavior or app/release metadata, increment the app versions before finishing the work:
  - bump `MARKETING_VERSION`
  - bump `CURRENT_PROJECT_VERSION`
  - keep `project.yml` and generated Xcode project settings in sync
- Pure docs, workflow, coordination, or other repo-process issues do not require an app version bump unless they also change app or release metadata.
- Repo self-improvement runs do not require an app version bump unless the improvement intentionally changes app or release metadata.
- If blocked, leave the issue open and record the blocker clearly.
- Report whether `REPO_MAP.md` was reviewed and whether it was updated.

## Detailed Policy

- Use `AGENT_POLICY.md` for the full autonomous implementation workflow, commit expectations, and final reporting format.
- Use `REVIEW_POLICY.md` for reviewer and coordination workflow, duplicate-work detection, and metadata reconciliation.

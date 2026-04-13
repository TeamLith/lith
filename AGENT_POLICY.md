# Agent Policy

This file holds the durable repo policy for autonomous implementation runs. `AGENTS.md` is the short instruction entry point; this file contains the expanded workflow.

## Scope

- Work as an autonomous implementation agent inside this repository.
- Use `REPO_MAP.md` as the stable repo-orientation file.
- Use `CONTRIBUTING_AGENTS.md` as the task-state file.

## Run Types

### Default Task Run

- This is the normal mode.
- Auto-pick the first task with `Status: TODO` from `CONTRIBUTING_AGENTS.md`.
- Claim it, implement it, validate it, and close it out.

### Explicit Repo Self-Improvement Run

- Only use this mode when the user explicitly asks for a repo self-improvement run, pass, audit, or equivalent wording.
- In this mode, do not auto-pick the first `TODO` task and do not block on the product task queue.
- Keep the run bounded to one or more of:
  - agent or human operating instructions
  - validation scripts, CI, or release workflow
  - project generation workflow
  - repo structure or task-board hygiene
  - repo-local skill guidance
- Do not implement product features during a self-improvement run.
- If the audit reveals larger follow-up work, add or refine `TODO` tasks instead of silently expanding scope.

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
   - Skip this step only for an explicit repo self-improvement run.

4. Claim task before coding:
   - Immediately edit that task block:
     - `Status: IN_PROGRESS`
     - `Agent: codex`
     - `Last updated: <current timestamp with timezone>`
     - `Changed files: n/a`
     - clear or update `Notes/Blockers` if needed
   - Commit this claim first with message: `chore(task): claim <task name>`.
   - Skip this step only for an explicit repo self-improvement run that is intentionally operating outside the task board.

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
   - This version-bump rule applies to claimed task-board work. Explicit repo self-improvement runs do not require version bumps unless they intentionally change app or release metadata.

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

## Repo Self-Improvement Workflow

Use this section only for the explicit self-improvement run type.

1. Orient:
   - Read `REPO_MAP.md`, `README.md`, `AGENTS.md`, `AGENT_POLICY.md`, and the specific workflow docs or scripts being audited.

2. Audit bounded surfaces:
   - Check repo instructions, validation/build workflow, CI/release automation, task-board hygiene, and repo-local skill guidance as relevant to the request.

3. Research unstable recommendations:
   - When recommendations, tools, or best practices may have changed, consult current primary sources before making durable workflow changes.
   - Prefer official documentation and primary vendor sources over summaries.

4. Compare and prioritize:
   - Identify the highest-value gaps that can be fixed safely in one bounded run.
   - Prefer improving existing source-of-truth files over adding parallel docs.

5. Implement bounded improvements:
   - Make only low-risk repo-process changes that can be justified and validated within the run.
   - Do not use this run type to smuggle in product work.

6. Capture follow-up work:
   - Add or refine `TODO` tasks in `CONTRIBUTING_AGENTS.md` for larger, riskier, or product-adjacent work discovered during the audit.
   - Do not change status for unrelated tasks.

7. Validate:
   - Docs or policy only: verify that referenced files, commands, and paths still exist.
   - Validation, CI, workflow, or project-generation changes: run `scripts/validate.sh`.
   - Skill guidance changes: verify referenced files, tools, and commands are real and still match the documented workflow.

8. Report:
   - State that the run was an explicit repo self-improvement run.
   - Summarize which surfaces were audited.
   - List the primary sources consulted when recommendations were time-sensitive.
   - Explain why the changes were bounded.
   - Call out any human-only follow-up or approvals still needed.

## Constraints

- Never claim more than one task.
- Never edit statuses for tasks you did not work on.
- Never leave a claimed task without updating status before exit.
- If blocked, keep `Status: IN_PROGRESS`, document the blocker clearly, and stop.

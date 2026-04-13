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

- This run type is separate from board-selected meta-improvement tasks.
- If a repo-workflow or meta-improvement task is already selected from `CONTRIBUTING_AGENTS.md`, treat it as a normal task run and follow the task-board workflow.
- Only use this explicit mode when the user directly asks for a repo self-improvement run, pass, audit, or equivalent wording outside the normal board selection flow.
- In this mode, do not auto-pick the first `TODO` task and do not require a selected board task before starting.
- Keep the run bounded to one or more of:
  - agent or human operating instructions
  - contributor workflow, intake, review, or handoff guidance
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

## Meta-Improvement Tasks

Use this section when the selected task improves the repository workflow itself rather than product behavior.

### Allowed Scope

- Treat repo self-improvement as valid only when the selected task explicitly targets repo workflow, docs, automation, or agent guidance.
- Keep the run bounded to one or more of:
  - repo instructions, task-board hygiene, or human-agent contribution workflow
  - contribution intake, review routing, or handoff guidance
  - validation scripts, CI, or project-generation workflow
  - cross-linked docs for humans and agents
  - repo-local skill maintenance for repeated repo-specific workflows
- Do not mix product feature implementation into a meta-improvement task.

### Bounded Checklist

1. Audit the current docs, scripts, or workflow files for the exact gap named by the task.
2. Prefer editing the current source-of-truth file instead of adding parallel guidance elsewhere.
3. Add cross-links only where discovery is weak; avoid duplicating large blocks of policy text.
4. For contributor-workflow audits, prefer standard GitHub-native collaboration surfaces when they reduce ambiguity, but do not add them speculatively without a clear repo-local benefit.
5. Keep changes reversible and low-risk; stop if the task would require secrets, account access, or speculative repo-wide restructuring.
6. Review `REPO_MAP.md` before close-out and update it only if durable repo orientation changed.

### Skill Maintenance

- Update an existing skill or instruction when the workflow already exists and only its steps, tools, constraints, or references changed.
- Add a new repo-local skill only when all of the following are true:
  - the workflow is repeated across tasks
  - it is repo-specific or too detailed for `AGENTS.md` and `AGENT_POLICY.md`
  - it has clear trigger conditions, inputs, outputs, and validation steps
  - the repo already has, or the task explicitly defines, an approved place to store that skill
- Do not create speculative skills for one-off work or to paper over missing product or process decisions.

### Human Escalation Boundary

- Agents may autonomously change repo docs, task metadata, validation scripts, CI or workflow files, and repo-local skills when the task explicitly calls for it and the change can be validated locally.
- Escalate to a human before changing or inventing:
  - secrets, credentials, Apple signing, team, or provisioning values
  - release approvals or App Store Connect state
  - repository admin settings, branch/ruleset enforcement, or ownership mappings that require access or policy decisions
  - legal or dependency license decisions
  - paid or external service setup or account ownership
  - destructive migrations or ambiguous repo-wide convention changes
  - one-time setup inputs that cannot be inferred safely

### Validation and Reporting

- Validate the exact surface changed:
  - docs or policy only: check that every referenced file, command, and path still exists, then report that no executable validation applied
  - `project.yml`, generated project files, validation scripts, or CI workflow changes: run `scripts/validate.sh`
  - new or updated repo-local skills: exercise the referenced commands or workflows where feasible and verify the skill points at real files
- Final reports for meta-improvement runs must also state:
  - why the changes were bounded
  - whether any human follow-up or one-time setup remains
  - why updating existing guidance was sufficient, or why a new skill was justified

## Repo Self-Improvement Workflow

Use this section only for the explicit repo self-improvement run type initiated outside the board.
Do not use this section for ordinary meta-improvement tasks that were selected from `CONTRIBUTING_AGENTS.md`; those remain standard task runs.

1. Orient:
   - Read `REPO_MAP.md`, `README.md`, `AGENTS.md`, `AGENT_POLICY.md`, and the specific workflow docs or scripts being audited.

2. Audit bounded surfaces:
   - Check repo instructions, contributor workflow and review/handoff norms, validation/build workflow, CI/release automation, task-board hygiene, and repo-local skill guidance as relevant to the request.

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

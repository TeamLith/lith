# Agent Policy

This file holds the durable repo policy for autonomous implementation runs. `AGENTS.md` is the short instruction entry point; this file contains the expanded workflow.

## Scope

- Work as an autonomous implementation agent inside this repository.
- Use `REPO_MAP.md` as the stable repo-orientation file.
- Use GitHub Issues as the authoritative task-state system.
- Use `CONTRIBUTING_AGENTS.md` only as a historical archive and migrated-backlog reference.

## Run Types

### Default Issue Run

- This is the normal mode.
- Work one GitHub Issue at a time.
- Prefer an explicitly provided or pre-assigned issue.
- If the environment supports GitHub assignment, claim the chosen issue on GitHub before implementation.
- If the environment cannot claim issues, do not auto-pick from the shared backlog in parallel mode.

### Explicit Repo Self-Improvement Run

- This run type is separate from board-selected meta-improvement tasks.
- If a repo-workflow or meta-improvement issue is already selected on GitHub, treat it as a normal issue run and follow the standard issue workflow.
- Only use this explicit mode when the user directly asks for a repo self-improvement run, pass, audit, or equivalent wording outside the normal board selection flow.
- In this mode, do not auto-pick product work and do not require a pre-created issue before starting.
- Keep the run bounded to one or more of:
  - agent or human operating instructions
  - contributor workflow, intake, review, or handoff guidance
  - validation scripts, CI, or release workflow
  - issue or pull request templates, labels, or project workflow guidance
  - project generation workflow
  - repo structure or task-board hygiene
  - repo-local skill guidance
- Do not implement product features during a self-improvement run.
- If the audit reveals larger follow-up work, add or refine GitHub Issues instead of silently expanding scope.

## Execution Rules

1. Sync first:
   - If the worktree is clean, checkout `main` and pull latest.
   - If the worktree is dirty or branch switching would risk unrelated changes, stop and report the condition instead of forcing sync.

2. Orient before coding:
   - Read `REPO_MAP.md` first.
   - Then read the selected GitHub Issue.
   - Then read `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, and only the feature or sync specs required by the selected issue.
   - Read `CONTRIBUTING_AGENTS.md` only if the chosen issue was seeded from the legacy board or the run is part of migration.

3. Select one issue:
   - Prefer an issue explicitly given by the user.
   - Otherwise prefer an issue already assigned to you.
   - If your environment can write to GitHub, claim an unassigned issue before coding.
   - If your environment cannot claim issues, stop and ask for an issue number or assignment instead of racing another agent.
   - Skip this step only for an explicit repo self-improvement run.

4. Create a task branch:
   - Create one feature branch for the chosen issue after the issue is clearly assigned or otherwise reserved.
   - Use one issue per branch and one PR per issue.

5. Implement only that one issue:
   - Read the required input specs listed in the issue body.
   - Make minimal, correct code and tests for the stated deliverables.
   - Do not implement unrelated tasks.

6. Avoid duplication:
   - Before adding code, check whether equivalent implementation already exists.
   - If the issue is already complete, do not re-implement it; comment or report that finding and stop.

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

9. Close issue work:
   - Update the linked issue or PR with concise notes, blockers, validation results, and any migration details when your environment supports GitHub writes.
   - If the issue is completed, increment app versions before the final implementation commit:
     - bump `MARKETING_VERSION`
     - bump `CURRENT_PROJECT_VERSION`
     - keep `project.yml` and generated Xcode project settings aligned
   - Explicit repo self-improvement runs do not require version bumps unless they intentionally change app or release metadata.

10. Commit and push:
   - Commit implementation with a clear message referencing the issue scope.
   - Push the branch, open one PR for the issue, and link the issue in the PR body.

11. Final report format:
   - Issue worked
   - What changed
   - Tests run and results
   - Whether `REPO_MAP.md` was reviewed
   - Whether `REPO_MAP.md` was updated, and why or why not
   - Any blockers
   - Exact files changed

## Meta-Improvement Tasks

Use this section when the selected issue or requested audit improves the repository workflow itself rather than product behavior.

### Allowed Scope

- Treat repo self-improvement as valid only when the selected issue or request explicitly targets repo workflow, docs, automation, or agent guidance.
- Keep the run bounded to one or more of:
  - repo instructions, task-board hygiene, or human-agent contribution workflow
  - contribution intake, issue/PR templates, review routing, or handoff guidance
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
- Agents may also add or update issue templates, pull request templates, and migration tooling for GitHub-native coordination.
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
  - repo-local migration or GitHub coordination scripts: run targeted syntax checks and dry-run parsing where feasible
  - new or updated repo-local skills: exercise the referenced commands or workflows where feasible and verify the skill points at real files
- Final reports for meta-improvement runs must also state:
  - why the changes were bounded
  - whether any human follow-up or one-time setup remains
  - why updating existing guidance was sufficient, or why a new skill was justified

## Repo Self-Improvement Workflow

Use this section only for the explicit repo self-improvement run type initiated outside the board.
Do not use this section for ordinary meta-improvement issues that were already created on GitHub; those remain standard issue runs.

1. Orient:
   - Read `REPO_MAP.md`, `README.md`, `AGENTS.md`, `AGENT_POLICY.md`, and the specific workflow docs or scripts being audited.

2. Audit bounded surfaces:
   - Check repo instructions, contributor workflow and review/handoff norms, issue/PR collaboration surfaces, validation/build workflow, CI/release automation, legacy task-board hygiene, and repo-local skill guidance as relevant to the request.

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
   - Add or refine GitHub Issues for larger, riskier, or product-adjacent work discovered during the audit.
   - Use `CONTRIBUTING_AGENTS.md` only as migration input until the backlog has moved.
   - Do not change status for unrelated tasks.

7. Validate:
   - Docs or policy only: verify that referenced files, commands, and paths still exist.
   - Validation, CI, workflow, or project-generation changes: run `scripts/validate.sh`.
   - Coordination or migration script changes: run targeted syntax checks and a dry-run migration smoke test where feasible.
   - Skill guidance changes: verify referenced files, tools, and commands are real and still match the documented workflow.

8. Report:
   - State that the run was an explicit repo self-improvement run.
   - Summarize which surfaces were audited.
   - List the primary sources consulted when recommendations were time-sensitive.
   - Explain why the changes were bounded.
   - Call out any human-only follow-up or approvals still needed.

## Constraints

- Never claim or work more than one GitHub Issue at a time.
- Never edit unrelated legacy task statuses in `CONTRIBUTING_AGENTS.md`.
- If blocked, keep the GitHub Issue open, document the blocker clearly, and stop.

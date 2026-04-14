# Contributing to Lith

Use GitHub-native workflow for tracked work. GitHub Issues are the source of truth for active work, ownership, and handoff. `CONTRIBUTING_AGENTS.md` remains only as legacy migration and archival context.

## Start With the Right Guide

- Humans: start with `HUMANS.md`.
- Autonomous implementation agents: start with `AGENTS.md`, then `AGENT_POLICY.md`.
- Reviewer or coordination agents: use `REVIEW_POLICY.md`.
- Explicit task-intake runs: use `AGENTS.md` and `AGENT_POLICY.md` to convert repo `## Task:` blocks into GitHub Issues without starting implementation.
- Everyone: use `REPO_MAP.md` to find the right spec files and canonical validation commands.

## Open or Claim One Issue

- Work one GitHub Issue at a time.
- Prefer an issue that is explicitly assigned, confirmed by a human, or otherwise clearly reserved before coding.
- Keep the issue open until the work is actually done; use assignment or a visible claim comment to show that it is in progress.
- If assignment is not available in the current environment, post a claim comment on the issue before creating a branch or editing files.
- If an open issue has neither an assignee nor a visible claim comment or linked PR, treat it as unclaimed.
- Use the `Feature Task` issue form for product or technical implementation and `Repo Self-Improvement` for docs, workflow, CI, release, or contributor-process improvements.
- If you need to capture fresh work from the repo `## Task:` markdown template instead of implementing immediately, use the explicit task-intake run so the work lands on GitHub rather than in `CONTRIBUTING_AGENTS.md`.
- If the issue changes user-facing behavior or adds a new feature, keep the matching user-facing documentation update in the same issue scope rather than treating docs as an optional later task.
- Keep one issue scoped to one branch and one pull request.
- Record blockers, validation notes, and handoff context on the GitHub Issue or linked pull request instead of in branch-local task state.

## Open a Pull Request

- Open a draft pull request early if you need feedback before the change is complete.
- Link the issue in the PR body. Use a closing keyword such as `Closes #123` only when merging the PR should close the issue.
- If the PR is only partial progress, reference the issue number in the body and link it from the GitHub Development sidebar instead of using a closing keyword.
- Summarize the scoped change, validation run, deferred follow-up, and any human-only setup or approvals still required.

## Validate Before Handoff

- Run the issue-specific commands listed in the specs or `REPO_MAP.md`.
- Use `scripts/validate.sh` when app wiring, project generation, CI/workflow files, or repo-process files changed.
- Verify that any user-visible feature, workflow, onboarding, or settings change also updated the user-facing documentation surface in scope.
- If the change is docs or policy only, verify that every referenced file, command, and path still exists unless the issue explicitly changes executable workflow behavior.

## Human-Only Decisions

- Humans own secrets, Apple signing, App Store Connect access, release approval, and repository admin settings.
- Humans also own label taxonomies, Projects configuration, rulesets, and any ownership mapping that would drive automatic review routing.
- `CODEOWNERS` is intentionally not enabled yet. GitHub requires explicit usernames or teams with write access, so review routing stays manual until a human-defined ownership map exists.

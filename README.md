# Lith

Native iOS/macOS note-taking app spec repo designed for multi-agent execution and human collaboration. The product is local-first with optional iCloud sync, starts with text notes and wiki-links, adds RSS approve-to-save workflows, then audio transcription and Siri-assisted action extraction, with Obsidian-like graph/search navigation.

The repository now uses GitHub Issues as the source of truth for active work. Repo-local Markdown task lists remain only as archival context plus a record of the legacy backlog that was migrated to GitHub.
For the GitHub-native contribution and review flow surfaced in Issues and pull requests, start with `CONTRIBUTING.md`.
User-facing documentation now lives in [`Docs/site`](./Docs/site/index.md) and is intended to publish through GitHub Pages once the repository Pages source is enabled for GitHub Actions.

## Tech constraints

- UI: Swift + SwiftUI
- Persistence: Core Data
- Sync: CloudKit (iCloud only in current roadmap)
- License policy: MIT (or more permissive) dependencies only
  - RSS: FeedKit / FeedParser (MIT)
  - Markdown rendering: Down / equivalent MIT-compatible parser/renderer

## Specs index

- [HUMANS.md](./HUMANS.md)
- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [AGENTS.md](./AGENTS.md)
- [AGENT_POLICY.md](./AGENT_POLICY.md)
- [REVIEW_POLICY.md](./REVIEW_POLICY.md)
- [PRODUCT_OVERVIEW.md](./PRODUCT_OVERVIEW.md)
- [REPO_MAP.md](./REPO_MAP.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [DATA_MODEL.md](./DATA_MODEL.md)
- [Docs/site/index.md](./Docs/site/index.md)
- [FEATURE_TEXT_NOTES.md](./FEATURE_TEXT_NOTES.md)
- [FEATURE_RSS_INBOX.md](./FEATURE_RSS_INBOX.md)
- [FEATURE_AUDIO_NOTES.md](./FEATURE_AUDIO_NOTES.md)
- [FEATURE_SIRI_INTELLIGENCE.md](./FEATURE_SIRI_INTELLIGENCE.md)
- [FEATURE_SEARCH_GRAPH.md](./FEATURE_SEARCH_GRAPH.md)
- [SYNC_ICLOUD.md](./SYNC_ICLOUD.md)
- [CONTRIBUTING_AGENTS.md](./CONTRIBUTING_AGENTS.md)
- [Docs/RELEASING_WITH_GITHUB.md](./Docs/RELEASING_WITH_GITHUB.md)

## How humans contribute

1. Start with `CONTRIBUTING.md` for the issue and PR workflow, then use `HUMANS.md` for setup and release-owned steps.
2. Use `README.md` and `REPO_MAP.md` to orient on the repo and find the right spec files.
3. Use GitHub Issues and, if desired, a GitHub Project board to coordinate tracked work with agents or other humans.
4. Update matching user-facing docs in `Docs/site` whenever behavior, onboarding, settings, or feature scope changes.
5. Run `scripts/validate.sh` before merging or handing work off.
6. Use `Docs/RELEASING_WITH_GITHUB.md` for signing, secrets, and TestFlight release steps.

## How AI agents contribute

1. Start with `AGENTS.md`.
2. Read orientation next: `REPO_MAP.md`.
3. Work from one GitHub Issue at a time, preferably one explicitly provided or assigned, and reserve it visibly on GitHub through assignment or a claim comment before coding.
4. Read global context next: `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`.
5. Read the relevant feature or sync file for that issue.
6. Implement code + tests.
7. If the issue changes user-facing behavior, onboarding, settings, workflows, or adds a new feature, update the matching user-facing page under `Docs/site` in the same scope.
8. Run the canonical validation flow for the changed area, preferring `scripts/validate.sh` when app/workflow wiring changed.
9. If the completed issue changes shipped app behavior or app/release metadata, bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, keeping `project.yml` and generated Xcode project settings in sync. Pure docs, workflow, coordination, or other repo self-improvement issues do not need a version bump unless they also change app/release metadata.
10. Review `REPO_MAP.md` before closing the work and update it only if repo orientation changed.
11. Include a short file-change summary for human or GitHub review and link the PR back to the issue.

Agents also support an explicit repo self-improvement run mode when a user asks for a repo self-improvement pass, audit, or equivalent. That mode bypasses normal issue selection, stays bounded to repo-process work such as agent/human instructions, contributor workflow, review/handoff norms, validation/CI/release automation, issue/PR templates, and repo-local skill guidance, and requires current primary sources when best-practice guidance may have changed.
Meta-improvement tasks still use the same one-issue workflow when they are tracked on GitHub. Use `AGENT_POLICY.md` for the dedicated checklist and `HUMANS.md` for human-only setup or approval inputs.

Agents also support an explicit task intake run mode when a user asks to add new tracked `TODO` items in the repo `## Task:` format. That mode converts one or more task blocks into GitHub Issues without starting implementation, keeps `CONTRIBUTING_AGENTS.md` archive-only, and uses the existing markdown-to-issue helper to create or preview the resulting issue payloads.

Reviewer or coordination sessions should start with `AGENTS.md` and then use `REVIEW_POLICY.md`.

## Pause and resume workflow

- Before pausing: update the GitHub Issue or linked PR with status, blockers, and next actions.
- On resume: continue from the assigned or linked GitHub Issue rather than scanning a branch-local task board.
- For handoff in low-token sessions: prioritize issue number, blockers, linked PR, and exact changed files.

# Lith

Native iOS/macOS note-taking app spec repo designed for multi-agent execution and human collaboration. The product is local-first with optional iCloud sync, starts with text notes and wiki-links, adds RSS approve-to-save workflows, then audio transcription and Siri-assisted action extraction, with Obsidian-like graph/search navigation.

## Tech constraints

- UI: Swift + SwiftUI
- Persistence: Core Data
- Sync: CloudKit (iCloud only in current roadmap)
- License policy: MIT (or more permissive) dependencies only
  - RSS: FeedKit / FeedParser (MIT)
  - Markdown rendering: Down / equivalent MIT-compatible parser/renderer

## Specs index

- [AGENTS.md](./AGENTS.md)
- [AGENT_POLICY.md](./AGENT_POLICY.md)
- [REVIEW_POLICY.md](./REVIEW_POLICY.md)
- [PRODUCT_OVERVIEW.md](./PRODUCT_OVERVIEW.md)
- [REPO_MAP.md](./REPO_MAP.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [DATA_MODEL.md](./DATA_MODEL.md)
- [FEATURE_TEXT_NOTES.md](./FEATURE_TEXT_NOTES.md)
- [FEATURE_RSS_INBOX.md](./FEATURE_RSS_INBOX.md)
- [FEATURE_AUDIO_NOTES.md](./FEATURE_AUDIO_NOTES.md)
- [FEATURE_SIRI_INTELLIGENCE.md](./FEATURE_SIRI_INTELLIGENCE.md)
- [FEATURE_SEARCH_GRAPH.md](./FEATURE_SEARCH_GRAPH.md)
- [SYNC_ICLOUD.md](./SYNC_ICLOUD.md)
- [CONTRIBUTING_AGENTS.md](./CONTRIBUTING_AGENTS.md)
- [Docs/RELEASING_WITH_GITHUB.md](./Docs/RELEASING_WITH_GITHUB.md)

## How AI agents contribute

1. Start with `AGENTS.md`.
2. Read orientation next: `REPO_MAP.md`.
3. Pick one task block from `CONTRIBUTING_AGENTS.md`.
4. Read global context next: `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`.
5. Read the relevant feature or sync file for that task.
6. Implement code + tests.
7. Update checklist status, `Agent`, and `Last updated` in `CONTRIBUTING_AGENTS.md`.
8. If the task is completed, bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, keeping `project.yml` and generated Xcode project settings in sync.
9. Review `REPO_MAP.md` before closing the task and update it only if repo orientation changed.
10. Include a short file-change summary for human or GitHub review.

Reviewer or coordination sessions should start with `AGENTS.md` and then use `REVIEW_POLICY.md`.

## Pause and resume workflow

- Before pausing: update task status (`TODO`/`IN_PROGRESS`/`DONE`) and leave next actions.
- On resume: start from the last `IN_PROGRESS` item in `CONTRIBUTING_AGENTS.md`.
- For handoff in low-token sessions: prioritize status + blockers + exact changed files.

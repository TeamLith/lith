# Contributing for Agents and Humans

This file is the task control plane for multi-agent execution and human review.

## 1. Global checklist

- [ ] Set up Swift Package / Xcode workspace. (see `ARCHITECTURE.md`)
- [ ] Implement Core Data model as per `DATA_MODEL.md`.
- [ ] Implement base UI shell (tab navigation, basic note list). (`FEATURE_TEXT_NOTES.md`)
- [ ] Implement text note CRUD. (`FEATURE_TEXT_NOTES.md`)
- [ ] Implement iCloud sync. (`SYNC_ICLOUD.md`)
- [ ] Implement RSS inbox. (`FEATURE_RSS_INBOX.md`)
- [ ] Implement audio recording + transcription. (`FEATURE_AUDIO_NOTES.md`)
- [ ] Implement Siri intent handling. (`FEATURE_SIRI_INTELLIGENCE.md`)
- [ ] Implement graph/search features. (`FEATURE_SEARCH_GRAPH.md`)
- [ ] Add unit/UI tests for critical flows. (`ARCHITECTURE.md`, feature specs)

## 2. Task template (copy for each new task)

```md
## Task: <Task name>

- Input specs:
  - <spec file>
- Deliverables:
  - <output 1>
  - <output 2>
- Steps:
  - [ ] <step 1>
  - [ ] <step 2>
  - [ ] <step 3>
- Status: TODO | IN_PROGRESS | DONE
- Agent: <name or system>
- Last updated: YYYY-MM-DD HH:mm TZ
- PR/Commit: <link or hash>
- Changed files:
  - <path>
  - <path>
- Notes/Blockers:
  - <only if needed>
```

## 3. Active task board

## Task: Implement Basic Note Entity

- Input specs:
  - `DATA_MODEL.md` (`Note` entity)
- Deliverables:
  - Core Data model changes
  - Unit tests for note CRUD
- Steps:
  - [x] Define Core Data entity `Note` with required fields.
  - [x] Generate model classes / repository mapping.
  - [x] Add CRUD repository API.
  - [x] Add tests in `NoteRepositoryTests`.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-12 14:50 IST
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - Sources/NativeNotes/Core/Models.swift
  - Sources/NativeNotes/Persistence/CoreDataNoteRepository.swift
  - Tests/NativeNotesTests/NoteRepositoryTests.swift
- Notes/Blockers:
  - n/a

## Task: Implement RSS Data Layer

- Input specs:
  - `DATA_MODEL.md` (`RssFeed`, `RssItem`)
  - `FEATURE_RSS_INBOX.md`
- Deliverables:
  - Feed/item persistence and upsert behavior
  - Parser mapping tests
- Steps:
  - [ ] Add `RssFeed` and `RssItem` data mappings.
  - [ ] Add repository methods for add/list/update/upsert.
  - [ ] Add tests for XML parser mapping and de-duplication.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27 00:00 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - n/a

## Task: Implement Search API

- Input specs:
  - `FEATURE_SEARCH_GRAPH.md`
  - `DATA_MODEL.md`
- Deliverables:
  - `SearchService.search(query:filters:)`
  - Test coverage for title/body/tags/metadata/transcript match
- Steps:
  - [ ] Add unified search entry point.
  - [ ] Implement filter support (source, dates, tags).
  - [ ] Add tests for query and filter combinations.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27 00:00 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - n/a

## 4. Pause/resume protocol (token-safe)

- Before stopping, every agent must update:
  - `Status`
  - `Last updated`
  - `Changed files`
  - `Notes/Blockers`
- If task is partially complete, set `Status: IN_PROGRESS` and add exact remaining steps.
- If blocked, include one-line unblock request and evidence.

## 5. GitHub collaboration protocol

- Work model:
  - one task -> one branch -> one PR
- Branch naming:
  - `feat/<task-slug>` or `fix/<task-slug>`
- PR requirements:
  - link task section in this file
  - include test evidence
  - include migration notes (if schema changed)
- Human review checklist:
  - requirement coverage
  - test completeness
  - data-model compatibility
  - rollback risk

## 6. Agent prompt pack

Use this bundle for each coding session:

1. `README.md`
2. `ARCHITECTURE.md`
3. `DATA_MODEL.md`
4. Relevant feature/sync spec
5. Relevant task section from this file

Prompt pattern:

> You are implementing `<Task Name>` from `CONTRIBUTING_AGENTS.md`.
> Use these specs: `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `<FEATURE_FILE>.md`, and the task block.
> Produce code and tests for a Swift/SwiftUI + Core Data project.
> Update task status/checklist and include changed-file summary.

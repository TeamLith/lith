# Contributing for Agents and Humans

This file is the task control plane for multi-agent execution and human review.

For stable repository orientation, read `REPO_MAP.md` before using this task board.

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
  - [x] Add `RssFeed` and `RssItem` data mappings.
  - [x] Add repository methods for add/list/update/upsert.
  - [x] Add tests for XML parser mapping and de-duplication.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-12 15:40 IST
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - Sources/NativeNotes/Core/Contracts.swift
  - Sources/NativeNotes/Core/Models.swift
  - Sources/NativeNotes/Persistence/CoreDataNoteRepository.swift
  - Sources/NativeNotes/Persistence/CoreDataRSSRepository.swift
  - Sources/NativeNotes/Services/InMemoryStores.swift
  - Tests/NativeNotesTests/NoteRepositoryTests.swift
  - Tests/NativeNotesTests/RSSRepositoryTests.swift
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
  - [x] Add unified search entry point.
  - [x] Implement filter support (source, dates, tags).
  - [x] Add tests for query and filter combinations.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-12 16:37 IST
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - Sources/NativeNotes/Core/Contracts.swift
  - Sources/NativeNotes/Services/SearchService.swift
  - Tests/NativeNotesTests/CoreBehaviorTests.swift
  - Tests/NativeNotesTests/SearchServiceTests.swift
- Notes/Blockers:
  - n/a

## Task: Set Up Xcode Workspace and App Targets

- Input specs:
  - `README.md`
  - `ARCHITECTURE.md`
  - `PRODUCT_OVERVIEW.md`
- Deliverables:
  - Xcode workspace/project for app development
  - Shared package integration for iOS and macOS app targets
  - Buildable app entry points on both platforms
- Steps:
  - [x] Create Xcode workspace/project structure using the existing Swift package.
  - [x] Add iOS and macOS SwiftUI app targets that link the shared package.
  - [x] Add shared schemes/configurations for local development and CI builds.
  - [x] Verify both app targets compile without feature wiring beyond bootstrapping.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-12 17:29:13 IST+0530
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - Package.swift
  - project.yml
  - NativeNotes.xcworkspace/contents.xcworkspacedata
  - NativeNotesApps.xcodeproj/project.pbxproj
  - NativeNotesApps.xcodeproj/project.xcworkspace/contents.xcworkspacedata
  - NativeNotesApps.xcodeproj/xcshareddata/xcschemes/NativeNotesiOS.xcscheme
  - NativeNotesApps.xcodeproj/xcshareddata/xcschemes/NativeNotesmacOS.xcscheme
  - Apps/NativeNotesApp/Sources/Shared/RootView.swift
  - Apps/NativeNotesApp/Sources/iOS/NativeNotesiOSApp.swift
  - Apps/NativeNotesApp/Sources/macOS/NativeNotesmacOSApp.swift
- Notes/Blockers:
  - n/a

## Task: Bootstrap App Persistence and Dependency Container

- Input specs:
  - `ARCHITECTURE.md`
  - `DATA_MODEL.md`
- Deliverables:
  - Shared persistence bootstrap for app runtime
  - Dependency container/environment wiring for repositories and services
- Steps:
  - [x] Define app-level dependency container for repositories and domain services.
  - [x] Configure persistent store loading for app and preview/test contexts.
  - [x] Inject dependencies into SwiftUI app roots for both iOS and macOS.
  - [x] Add smoke tests or previews for container startup behavior.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-12 17:51:47 IST+0530
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - Sources/NativeNotes/AppDependencyContainer.swift
  - Apps/NativeNotesApp/Sources/Shared/RootView.swift
  - Apps/NativeNotesApp/Sources/iOS/NativeNotesiOSApp.swift
  - Apps/NativeNotesApp/Sources/macOS/NativeNotesmacOSApp.swift
  - Tests/NativeNotesTests/AppDependencyContainerTests.swift
- Notes/Blockers:
  - n/a

## Task: Implement Base UI Shell

- Input specs:
  - `ARCHITECTURE.md`
  - `FEATURE_TEXT_NOTES.md`
- Deliverables:
  - SwiftUI shell with top-level navigation
  - Placeholder screens for major product areas
- Steps:
  - [x] Build root navigation shell for notes, RSS, search/graph, and settings.
  - [x] Support platform-appropriate navigation patterns on iOS and macOS.
  - [x] Add placeholder empty states for unfinished sections.
  - [x] Add lightweight UI tests or previews for shell navigation.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-13 03:37:32 IST +0530
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - Apps/LithApp/Sources/Shared/RootView.swift
- Notes/Blockers:
  - n/a

## Task: Implement Note List and Detail UI

- Input specs:
  - `FEATURE_TEXT_NOTES.md`
  - `ARCHITECTURE.md`
  - `DATA_MODEL.md`
- Deliverables:
  - SwiftUI notes list screen
  - SwiftUI note detail/editor screen
- Steps:
  - [x] Build note list sections for pinned and recent notes.
  - [x] Build note detail editor with markdown-first editing flow.
  - [x] Add note selection/navigation behavior for iOS and macOS.
  - [x] Add previews or UI tests for populated and empty states.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-12 22:35 UTC
- PR/Commit: feat/note-list-detail-ui
- Changed files:
  - Sources/Lith/UI/NoteListViewModel.swift
  - Apps/LithApp/Sources/Shared/Notes/NoteListView.swift
  - Apps/LithApp/Sources/Shared/Notes/NoteDetailView.swift
  - Apps/LithApp/Sources/Shared/RootView.swift
  - Tests/LithTests/NoteListViewModelTests.swift
- Notes/Blockers:
  - n/a

## Task: Wire Note CRUD Flows Into UI

- Input specs:
  - `FEATURE_TEXT_NOTES.md`
  - `DATA_MODEL.md`
- Deliverables:
  - Create/edit/delete flows backed by `NoteRepository`
  - Basic list refresh and persistence behavior
- Steps:
  - [ ] Wire note creation from the list UI into repository-backed persistence.
  - [ ] Wire note editing and autosave/update behavior in note detail.
  - [ ] Add archive/delete or trash interactions consistent with the data model.
  - [ ] Add tests covering repository-backed CRUD flows from UI-facing view models.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement Note List and Detail UI`.

## Task: Implement Wikilink Parsing and Link Persistence

- Input specs:
  - `FEATURE_TEXT_NOTES.md`
  - `DATA_MODEL.md` (`Link`)
- Deliverables:
  - Wikilink parsing and resolution pipeline
  - Link persistence/backlink query support
- Steps:
  - [ ] Parse `[[...]]` references from note markdown.
  - [ ] Resolve links against existing notes and persist `Link` records.
  - [ ] Expose backlink queries for note detail presentation.
  - [ ] Add parser and persistence tests for create/update scenarios.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Wire Note CRUD Flows Into UI`.

## Task: Implement RSS Fetcher

- Input specs:
  - `FEATURE_RSS_INBOX.md`
  - `ARCHITECTURE.md`
- Deliverables:
  - Feed fetch service around RSS parser dependency
  - Manual refresh workflow and error handling
- Steps:
  - [ ] Wrap FeedKit or equivalent MIT-compatible parser behind an adapter boundary.
  - [ ] Implement manual refresh fetching for configured feeds.
  - [ ] Map parser output into RSS repository upsert operations.
  - [ ] Add tests for success, malformed feed, and retryable error paths.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement RSS Data Layer`.

## Task: Implement RSS Inbox UI

- Input specs:
  - `FEATURE_RSS_INBOX.md`
  - `ARCHITECTURE.md`
  - `DATA_MODEL.md`
- Deliverables:
  - SwiftUI RSS inbox grouped by feed/category
  - Approve-to-save note workflow
- Steps:
  - [ ] Build feed and item list UI with grouped sections.
  - [ ] Add refresh and item state controls (`new`, `approved`, `ignored`).
  - [ ] Implement `Approve -> Save as Note` flow with source metadata linkage.
  - [ ] Add UI/view-model tests for approval and save behavior.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement RSS Fetcher`.

## Task: Implement Search UI

- Input specs:
  - `FEATURE_SEARCH_GRAPH.md`
  - `ARCHITECTURE.md`
- Deliverables:
  - Search screen with query input and filters
  - Navigation from search results to note detail
- Steps:
  - [ ] Build search input and filter controls for source, dates, and tags.
  - [ ] Render result list with snippets and metadata badges.
  - [ ] Wire result navigation to note detail.
  - [ ] Add UI/view-model tests for query and filter behavior.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement Search API`.

## Task: Implement Graph Data Builder

- Input specs:
  - `FEATURE_SEARCH_GRAPH.md`
  - `DATA_MODEL.md` (`Note`, `Link`)
- Deliverables:
  - Repository-backed graph projection API
  - Local neighborhood filtering support
- Steps:
  - [ ] Read notes and links from persistence-backed repositories.
  - [ ] Build graph projection structs for global and local graph modes.
  - [ ] Add bounded depth filtering for local graph exploration.
  - [ ] Add tests covering projection correctness and filtering behavior.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement Wikilink Parsing and Link Persistence`.

## Task: Implement Graph View

- Input specs:
  - `FEATURE_SEARCH_GRAPH.md`
  - `ARCHITECTURE.md`
- Deliverables:
  - Interactive graph screen
  - Navigation from graph nodes to note detail
- Steps:
  - [ ] Render graph nodes and edges with an initial deterministic layout.
  - [ ] Add pan/zoom and node selection behavior.
  - [ ] Support local graph mode centered on a selected note.
  - [ ] Add UI or snapshot coverage for core graph interactions.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement Graph Data Builder`.

## Task: Implement CloudKit Schema

- Input specs:
  - `SYNC_ICLOUD.md`
  - `DATA_MODEL.md`
- Deliverables:
  - CloudKit record mapping definitions
  - Migration/index documentation for sync entities
- Steps:
  - [ ] Map each synced entity to a CloudKit record type and field set.
  - [ ] Define required indexes and conflict-resolution metadata.
  - [ ] Document migration expectations for future field additions.
  - [ ] Add tests or validation helpers for mapping integrity where feasible.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - n/a

## Task: Implement Sync Engine

- Input specs:
  - `SYNC_ICLOUD.md`
  - `ARCHITECTURE.md`
- Deliverables:
  - iCloud sync adapter over persistent storage
  - Sync status/error reporting pipeline
- Steps:
  - [ ] Integrate `NSPersistentCloudKitContainer` or equivalent CloudKit-backed path.
  - [ ] Implement pull/push cycle handling with retry/throttle behavior.
  - [ ] Record sync status and recoverable errors for UI presentation.
  - [ ] Add integration-style tests for disabled iCloud and conflict paths where feasible.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement CloudKit Schema`.

## Task: Implement iCloud Settings UI

- Input specs:
  - `SYNC_ICLOUD.md`
  - `ARCHITECTURE.md`
- Deliverables:
  - Settings controls for sync enablement and status
  - Last-sync and error presentation
- Steps:
  - [ ] Add iCloud enable/disable controls in settings.
  - [ ] Show sync status and last successful sync timestamp.
  - [ ] Surface recoverable error messaging and retry entry points.
  - [ ] Add UI/view-model tests for sync settings behavior.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement Sync Engine`.

## Task: Implement Audio Recording Infrastructure

- Input specs:
  - `FEATURE_AUDIO_NOTES.md`
  - `DATA_MODEL.md` (`AudioNote`)
- Deliverables:
  - Recording service and local/iCloud file lifecycle
  - `AudioNote` persistence wiring
- Steps:
  - [ ] Implement recording service using Apple audio APIs.
  - [ ] Persist deterministic audio file locations by note/recording ID.
  - [ ] Persist `AudioNote` metadata and interruption/error states.
  - [ ] Add tests for file naming, metadata persistence, and failure handling.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Wire Note CRUD Flows Into UI`.

## Task: Implement Transcription Service

- Input specs:
  - `FEATURE_AUDIO_NOTES.md`
  - `ARCHITECTURE.md`
- Deliverables:
  - Speech transcription service
  - Transcript/status persistence workflow
- Steps:
  - [ ] Implement speech transcription using Apple Speech framework.
  - [ ] Persist transcript text and `transcriptionStatus`.
  - [ ] Expose progress/completion updates for UI consumption.
  - [ ] Add tests or protocol-backed fakes for transcription state handling.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement Audio Recording Infrastructure`.

## Task: Implement Audio UI

- Input specs:
  - `FEATURE_AUDIO_NOTES.md`
  - `ARCHITECTURE.md`
- Deliverables:
  - Recording/playback controls in note detail
  - Transcript presentation and correction UI
- Steps:
  - [ ] Add record/stop/playback controls to note detail.
  - [ ] Show recording duration and transcription progress.
  - [ ] Render transcript with editable correction support.
  - [ ] Add UI/view-model tests for recording and transcript states.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement Transcription Service`.

## Task: Implement Basic App Intent for Create Note

- Input specs:
  - `FEATURE_SIRI_INTELLIGENCE.md`
  - `ARCHITECTURE.md`
  - `DATA_MODEL.md` (`Note`)
- Deliverables:
  - App Intent for note creation
  - Domain-service wiring and confirmation response
- Steps:
  - [ ] Define create-note App Intent parameters and response model.
  - [ ] Wire intent execution to note creation in shared services.
  - [ ] Add intent availability to the iOS app target.
  - [ ] Add tests for parameter mapping and note creation behavior.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Wire Note CRUD Flows Into UI`.

## Task: Implement Transcript Action Item Extractor

- Input specs:
  - `FEATURE_SIRI_INTELLIGENCE.md`
  - `DATA_MODEL.md` (`ActionItem`)
- Deliverables:
  - Transcript-to-action-item extraction pipeline
  - Persistence path for accepted action items
- Steps:
  - [ ] Parse transcript text into structured action-item drafts.
  - [ ] Add heuristic date/assignee detection rules.
  - [ ] Persist accepted items as `ActionItem` records.
  - [ ] Add tests using canned transcript fixtures and edge cases.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement Transcription Service`.

## Task: Implement Action Item UI

- Input specs:
  - `FEATURE_SIRI_INTELLIGENCE.md`
  - `ARCHITECTURE.md`
- Deliverables:
  - Structured checklist UI under transcripts/notes
  - Edit and mark-done flows
- Steps:
  - [ ] Render action items in note detail or transcript review UI.
  - [ ] Support mark-done, edit, and delete interactions.
  - [ ] Add acceptance/review gate before exporting or reminding.
  - [ ] Add UI/view-model tests for action item lifecycle behavior.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Depends on `Implement Transcript Action Item Extractor`.

## Task: Add Critical Flow Test Coverage

- Input specs:
  - `ARCHITECTURE.md`
  - Relevant feature specs for completed flows
- Deliverables:
  - Unit/UI/integration coverage for primary user journeys
  - Documented test matrix for regression prevention
- Steps:
  - [ ] Add test coverage for note CRUD, RSS approval, and search flows.
  - [ ] Add UI coverage for navigation shell and primary screens.
  - [ ] Add integration coverage for persistence startup and sync-disabled mode.
  - [ ] Document remaining test gaps and deferred scenarios.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-04-12 15:12 IST
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Run after the corresponding product flows exist.

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

1. `REPO_MAP.md`
2. `README.md`
3. `ARCHITECTURE.md`
4. `DATA_MODEL.md`
5. Relevant feature/sync spec
6. Relevant task section from this file

Prompt pattern:

> You are implementing `<Task Name>` from `CONTRIBUTING_AGENTS.md`.
> Use these specs: `REPO_MAP.md`, `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `<FEATURE_FILE>.md`, and the task block.
> Produce code and tests for a Swift/SwiftUI + Core Data project.
> Update task status/checklist and include changed-file summary.

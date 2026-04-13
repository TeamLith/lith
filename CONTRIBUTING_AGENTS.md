# Contributing for Agents and Humans

This file is a legacy task inventory and migration source. GitHub Issues are now the source of truth for active work, assignment, and parallel execution.

For repo-local agent instructions, start with `AGENTS.md`.
For stable repository orientation, read `REPO_MAP.md`.
For reviewer or coordination runs, also use `REVIEW_POLICY.md`.

## Migration Status

- Active and future work should be created and tracked as GitHub Issues.
- The legacy TODO backlog below was imported into GitHub Issues `#21` through `#36` on 2026-04-13.
- The per-task `Status` values below are archive snapshots from the Markdown board, not the live source of truth.
- Use `python3 scripts/migrate_pending_tasks_to_github_issues.py --create` with `GITHUB_TOKEN` or `GH_TOKEN` set only for future one-off legacy imports.
- Do not treat branch-local edits to this file as a coordination lock.
- Keep this file as historical context, migration record, and prompt-pack archive unless a later cleanup intentionally archives it further.

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

## 3. Legacy task inventory

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
  - Sources/Lith/Core/Models.swift
  - Sources/Lith/Persistence/CoreDataNoteRepository.swift
  - Tests/LithTests/NoteRepositoryTests.swift
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
  - Sources/Lith/Core/Contracts.swift
  - Sources/Lith/Core/Models.swift
  - Sources/Lith/Persistence/CoreDataNoteRepository.swift
  - Sources/Lith/Persistence/CoreDataRSSRepository.swift
  - Sources/Lith/Services/InMemoryStores.swift
  - Tests/LithTests/NoteRepositoryTests.swift
  - Tests/LithTests/RSSRepositoryTests.swift
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
  - Sources/Lith/Core/Contracts.swift
  - Sources/Lith/Services/SearchService.swift
  - Tests/LithTests/CoreBehaviorTests.swift
  - Tests/LithTests/SearchServiceTests.swift
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
  - Lith.xcworkspace/contents.xcworkspacedata
  - LithApps.xcodeproj/project.pbxproj
  - LithApps.xcodeproj/project.xcworkspace/contents.xcworkspacedata
  - LithApps.xcodeproj/xcshareddata/xcschemes/LithiOS.xcscheme
  - LithApps.xcodeproj/xcshareddata/xcschemes/LithmacOS.xcscheme
  - Apps/LithApp/Sources/Shared/RootView.swift
  - Apps/LithApp/Sources/iOS/LithiOSApp.swift
  - Apps/LithApp/Sources/macOS/LithmacOSApp.swift
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
  - Sources/Lith/AppDependencyContainer.swift
  - Apps/LithApp/Sources/Shared/RootView.swift
  - Apps/LithApp/Sources/iOS/LithiOSApp.swift
  - Apps/LithApp/Sources/macOS/LithmacOSApp.swift
  - Tests/LithTests/AppDependencyContainerTests.swift
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
  - [x] Wire note creation from the list UI into repository-backed persistence.
  - [x] Wire note editing and autosave/update behavior in note detail.
  - [x] Add archive/delete or trash interactions consistent with the data model.
  - [x] Add tests covering repository-backed CRUD flows from UI-facing view models.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-13 04:39:13 IST +0530
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - Sources/Lith/UI/NoteListViewModel.swift
  - Sources/Lith/UI/NoteDetailViewModel.swift
  - Apps/LithApp/Sources/Shared/Notes/NoteListView.swift
  - Apps/LithApp/Sources/Shared/Notes/NoteDetailView.swift
  - Apps/LithApp/Sources/Shared/RootView.swift
  - Tests/LithTests/NoteListViewModelTests.swift
  - Tests/LithTests/NoteDetailViewModelTests.swift
- Notes/Blockers:
  - n/a

## Task: Implement Wikilink Parsing and Link Persistence

- Input specs:
  - `FEATURE_TEXT_NOTES.md`
  - `DATA_MODEL.md` (`Link`)
- Deliverables:
  - Wikilink parsing and resolution pipeline
  - Link persistence/backlink query support
- Steps:
  - [x] Parse `[[...]]` references from note markdown.
  - [x] Resolve links against existing notes and persist `Link` records.
  - [x] Expose backlink queries for note detail presentation.
  - [x] Add parser and persistence tests for create/update scenarios.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-13 14:37:06 IST +0530
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - REPO_MAP.md
  - project.yml
  - LithApps.xcodeproj/project.pbxproj
  - Sources/Lith/AppDependencyContainer.swift
  - Sources/Lith/Core/Contracts.swift
  - Sources/Lith/Core/Models.swift
  - Sources/Lith/Persistence/CoreDataLinkRepository.swift
  - Sources/Lith/Persistence/CoreDataNoteRepository.swift
  - Sources/Lith/Services/InMemoryStores.swift
  - Sources/Lith/Services/WikiLinkParser.swift
  - Sources/Lith/Services/WikiLinkService.swift
  - Sources/Lith/UI/NoteDetailViewModel.swift
  - Apps/LithApp/Sources/Shared/RootView.swift
  - Apps/LithApp/Sources/Shared/Notes/NoteListView.swift
  - Apps/LithApp/Sources/Shared/Notes/NoteDetailView.swift
  - Tests/LithTests/AppDependencyContainerTests.swift
  - Tests/LithTests/CoreBehaviorTests.swift
  - Tests/LithTests/LinkRepositoryTests.swift
  - Tests/LithTests/NoteDetailViewModelTests.swift
  - Tests/LithTests/WikiLinkServiceTests.swift
- Notes/Blockers:
  - Added Core Data-backed wikilink persistence, view-model backlink presentation, and task-close version sync. REPO_MAP reviewed and updated for new durable wikilink paths.

## Task: Establish Human and Agent Operating Framework

- Input specs:
  - `README.md`
  - `REPO_MAP.md`
  - `AGENTS.md`
  - `AGENT_POLICY.md`
  - `Docs/RELEASING_WITH_GITHUB.md`
- Deliverables:
  - A root-level `HUMANS.md` for human operators
  - Updated cross-links in repo docs for human and agent workflows
  - One-time setup checklist for humans
- Steps:
  - [x] Audit the current human and agent workflows across repo docs.
  - [x] Create `HUMANS.md` covering setup, local development, testing, project generation, and release flow.
  - [x] Clarify where humans vs agents should make changes and what requires one-time human setup.
  - [x] Update links in existing docs so the workflow is discoverable.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-13 17:33:58 IST +0530
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - HUMANS.md
  - README.md
  - AGENTS.md
  - REPO_MAP.md
  - Docs/RELEASING_WITH_GITHUB.md
  - project.yml
  - LithApps.xcodeproj/project.pbxproj
- Notes/Blockers:
  - Added a dedicated human operator guide, cross-linked human and agent entry points, reviewed and updated REPO_MAP for the new durable workflow path, and synced app version metadata to 0.1.3 (4).

## Task: Align Build and Release Workflow to Current Best Practices

- Input specs:
  - `README.md`
  - `ARCHITECTURE.md`
  - `REPO_MAP.md`
  - `project.yml`
  - `Docs/RELEASING_WITH_GITHUB.md`
- Deliverables:
  - Internet-researched build/release workflow improvements
  - Repo changes to match the chosen workflow
  - Validation notes and rationale for each durable workflow change
- Steps:
  - [x] Research current best practices from primary sources for Swift package + XcodeGen + Apple app workflows.
  - [x] Compare the current repo workflow against those practices and identify the highest-value gaps.
  - [x] Implement the justified workflow, script, doc, or structure changes.
  - [x] Validate builds/tests and document any one-time human setup needed.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-13 19:34:49 IST +0530
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - .github/workflows/release-testflight.yml
  - .github/workflows/validate.yml
  - Docs/RELEASING_WITH_GITHUB.md
  - HUMANS.md
  - LithApps.xcodeproj/project.pbxproj
  - README.md
  - REPO_MAP.md
  - project.yml
  - scripts/validate.sh
- Notes/Blockers:
  - Added a shared validation script, a pull request/main validation workflow, and release preflight validation with XcodeGen regeneration from `project.yml`. REPO_MAP reviewed and updated for the new durable workflow paths. Human still owns signing/team configuration and App Store Connect secrets.

## Task: Add Repo Self-Improvement Loop and Skill Maintenance

- Input specs:
  - `AGENTS.md`
  - `AGENT_POLICY.md`
  - `REPO_MAP.md`
  - `README.md`
- Deliverables:
  - A defined recurring repo-improvement workflow for future agent runs
  - Repo-local guidance for when to update or add skills
  - Human-readable instructions for approving or supplying one-time setup inputs
- Steps:
  - [x] Define a bounded “improve the project itself” checklist agents can execute safely on future runs.
  - [x] Add guidance for when to update existing skills vs define new ones.
  - [x] Document what agents may change autonomously and what must be escalated to a human.
  - [x] Add validation and reporting expectations for meta-improvement runs.
- Status: DONE
- Agent: codex
- Last updated: 2026-04-13 19:58:19 IST +0530
- PR/Commit: n/a
- Changed files:
  - CONTRIBUTING_AGENTS.md
  - AGENTS.md
  - AGENT_POLICY.md
  - README.md
  - HUMANS.md
  - project.yml
  - LithApps.xcodeproj/project.pbxproj
- Notes/Blockers:
  - Added bounded meta-improvement and skill-maintenance guidance plus an explicit repo self-improvement run mode that bypasses the normal first-`TODO` flow when requested, clarified human-only approval/setup inputs, reviewed `REPO_MAP.md` without updating it, and synced app versions to 0.1.5 (6).

## Task: Audit Contributor Collaboration Workflow

- GitHub Issue: `#21`

- Input specs:
  - `README.md`
  - `AGENTS.md`
  - `AGENT_POLICY.md`
  - `HUMANS.md`
  - `REVIEW_POLICY.md`
- Deliverables:
  - Current-source audit of contributor and agent collaboration workflow
  - Justified improvements to contribution intake, review, handoff, or ownership-routing guidance
  - Clear rationale for any collaboration surface intentionally not adopted
- Steps:
- [ ] Compare the current collaboration workflow against current primary-source GitHub guidance.
- [ ] Identify the highest-value missing or unclear contribution/review surfaces.
- [ ] Implement only low-risk repo-local changes that improve contribution quality or review routing.
- [ ] Document any human-only follow-up, admin settings, or ownership decisions still required.
- Status: IN_PROGRESS
- Agent: codex
- Last updated: 2026-04-13 21:44:54 IST +0530
- PR/Commit: n/a
- Changed files:
  - n/a
- Notes/Blockers:
  - Keep bounded to contributor experience and repo workflow. Do not implement product features or rely on repo-admin settings without human approval.

## Task: Implement RSS Fetcher

- GitHub Issue: `#22`

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

- GitHub Issue: `#23`

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

- GitHub Issue: `#24`

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

- GitHub Issue: `#25`

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

- GitHub Issue: `#26`

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

- GitHub Issue: `#27`

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

- GitHub Issue: `#28`

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

- GitHub Issue: `#29`

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

- GitHub Issue: `#30`

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

- GitHub Issue: `#31`

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

- GitHub Issue: `#32`

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

- GitHub Issue: `#33`

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

- GitHub Issue: `#34`

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

- GitHub Issue: `#35`

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

- GitHub Issue: `#36`

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

## 4. Legacy pause/resume protocol (token-safe)

- Prefer GitHub Issues and PR comments for pause/resume state.
- If a legacy task has not yet been migrated and work must be paused, update:
  - `Status`
  - `Last updated`
  - `Changed files`
  - `Notes/Blockers`
- If task is partially complete, set `Status: IN_PROGRESS` and add exact remaining steps.
- If blocked, include one-line unblock request and evidence.

## 5. GitHub collaboration protocol

- Work model:
  - one GitHub Issue -> one assignee -> one branch -> one PR
- Source of truth:
  - GitHub Issue assignment is the lock for active work.
  - GitHub Projects, labels, and milestones are the preferred board/status surfaces.
  - This file is only a migration source for legacy tasks and should not be used as the live lock.
- Branch naming:
  - `feat/<issue-slug>` or `fix/<issue-slug>`
- PR requirements:
  - link the GitHub Issue
  - include test evidence
  - include migration notes (if schema changed)
- Human review checklist:
  - requirement coverage
  - test completeness
  - data-model compatibility
  - rollback risk

## 6. Agent prompt pack

Use this bundle for each coding session:

1. `AGENTS.md`
2. `REPO_MAP.md`
3. `README.md`
4. `ARCHITECTURE.md`
5. `DATA_MODEL.md`
6. Relevant feature/sync spec
7. Relevant GitHub Issue
8. Relevant legacy task section from this file only when migrating an unmigrated task

Prompt pattern:

> You are implementing GitHub Issue `#<number>: <Issue Title>`.
> Use these specs: `AGENTS.md`, `REPO_MAP.md`, `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `<FEATURE_FILE>.md`, and the issue body.
> If this issue was seeded from the legacy backlog, also use the matching task block in `CONTRIBUTING_AGENTS.md`.
> Produce code and tests for a Swift/SwiftUI + Core Data project.
> Review whether `REPO_MAP.md` needs changes, include changed-file summary, and link the PR back to the issue.

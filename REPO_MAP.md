# Repo Map

This file is the stable orientation guide for future agent and human sessions. Read this before scanning the full repository.

## Purpose

- Use this file to understand the current project layout, primary entry points, and where to make changes.
- Use `HUMANS.md` for human setup, validation, and release-owner responsibilities.
- Use `CONTRIBUTING_AGENTS.md` for task state and handoff details.
- Update this file only when repository structure, ownership boundaries, or core build workflows materially change.

## Project Shape

Lith is split into:

- A Swift package named `Lith` for shared domain, persistence, services, graph logic, and view models.
- Xcode app targets for iOS and macOS under `Apps/LithApp`.
- Markdown specs and roadmap documents at the repository root and under `Docs`.

## Read Order

Read only what matches the task:

- Autonomous agents:
  1. `AGENTS.md`
  2. `REPO_MAP.md`
  3. `CONTRIBUTING_AGENTS.md`
  4. `README.md`
  5. One or more of:
     - `ARCHITECTURE.md`
     - `DATA_MODEL.md`
     - relevant `FEATURE_*.md`
     - relevant `Docs/*.md`
- Humans:
  1. `HUMANS.md`
  2. `README.md`
  3. `REPO_MAP.md`
  4. `CONTRIBUTING_AGENTS.md` when coordinating tracked work
  5. relevant `FEATURE_*.md`, `SYNC_ICLOUD.md`, or `Docs/*.md`

## High-Value Paths

### Product and planning

- `README.md`: top-level product summary and contributor workflow.
- `HUMANS.md`: human operator setup, validation, and release-owner guide.
- `AGENTS.md`: repo-local default instruction file for autonomous agents.
- `AGENT_POLICY.md`: expanded autonomous workflow and reporting policy.
- `REVIEW_POLICY.md`: reviewer and coordination workflow for duplicate detection and tracker hygiene.
- `ARCHITECTURE.md`: app layering, responsibilities, and architectural constraints.
- `DATA_MODEL.md`: entities and persistence model.
- `FEATURE_TEXT_NOTES.md`
- `FEATURE_RSS_INBOX.md`
- `FEATURE_AUDIO_NOTES.md`
- `FEATURE_SIRI_INTELLIGENCE.md`
- `FEATURE_SEARCH_GRAPH.md`
- `SYNC_ICLOUD.md`
- `CONTRIBUTING_AGENTS.md`: task board, pause/resume protocol, prompt pack.
- `Docs/RELEASING_WITH_GITHUB.md`: human-owned signing, secrets, and TestFlight release workflow.

### Shared package

- `Package.swift`: Swift package definition for the shared `Lith` module and tests.
- `Sources/Lith/Lith.swift`: package entry marker.
- `Sources/Lith/AppDependencyContainer.swift`: app bootstrap and dependency wiring.
- `Sources/Lith/Core`: shared models and contracts.
- `Sources/Lith/Persistence`: Core Data repositories.
- `Sources/Lith/Persistence/CoreDataLinkRepository.swift`: persisted wikilink/backlink storage.
- `Sources/Lith/Services`: search, RSS conversion, wiki links, action extraction, and test/in-memory support.
- `Sources/Lith/Services/WikiLinkService.swift`: wikilink resolution and backlink queries.
- `Sources/Lith/Graph`: graph models and builder logic.
- `Sources/Lith/Sync`: sync conflict handling.
- `Sources/Lith/UI`: shared UI-facing view models.

### App targets

- `project.yml`: source of truth for generating the Xcode project with XcodeGen.
- `LithApps.xcodeproj`: generated project artifact. Regenerate after structural source changes.
- `Apps/LithApp/Sources/Shared/RootView.swift`: top-level app shell used by both platforms.
- `Apps/LithApp/Sources/Shared/Notes`: SwiftUI note list/detail screens shared across app targets.
- `Apps/LithApp/Sources/iOS/LithiOSApp.swift`: iOS app entry point.
- `Apps/LithApp/Sources/macOS/LithmacOSApp.swift`: macOS app entry point.
- `Apps/LithApp/Resources`: app assets.

### Tests

- `Tests/LithTests`: package tests covering repositories, services, dependency setup, and view models.

## Build and Validation Shortcuts

- Package build: `swift build`
- Package tests: `swift test`
- macOS app build:
  `xcodebuild -scheme LithmacOS -project LithApps.xcodeproj -configuration Debug -destination 'platform=macOS' build`
- iOS app build:
  `xcodebuild -scheme LithiOS -project LithApps.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Regenerate Xcode project after target/source layout changes: `xcodegen generate`

## Known Conventions

- Prefer changing shared logic under `Sources/Lith` unless the work is truly app-shell-specific.
- Prefer adding UI state logic to `Sources/Lith/UI` and keeping SwiftUI views in `Apps/LithApp/Sources`.
- Treat `project.yml` as authoritative for target structure. If `LithApps.xcodeproj` and source layout diverge, regenerate the project.
- Keep `CONTRIBUTING_AGENTS.md` updated for task progress, but keep long-lived repo structure knowledge here.
- Keep durable workflow rules in `AGENTS.md` and `AGENT_POLICY.md`, not in copy-pasted prompts.

## Fast Routing Guide

- Note CRUD, repositories, and entities:
  start with `DATA_MODEL.md`, `Sources/Lith/Core`, `Sources/Lith/Persistence`, `Sources/Lith/Services/WikiLinkService.swift`, and `Tests/LithTests`.
- SwiftUI shell or screens:
  start with `Apps/LithApp/Sources/Shared`, platform app entry points, and `FEATURE_TEXT_NOTES.md`.
- Search or graph:
  start with `FEATURE_SEARCH_GRAPH.md`, `Sources/Lith/Services/SearchService.swift`, and `Sources/Lith/Graph`.
- RSS:
  start with `FEATURE_RSS_INBOX.md`, `Sources/Lith/Services/RSSConversionService.swift`, and `Sources/Lith/Persistence/CoreDataRSSRepository.swift`.
- Sync:
  start with `SYNC_ICLOUD.md`, `Sources/Lith/AppDependencyContainer.swift`, and `Sources/Lith/Sync`.

## Maintenance Rule

Update this file when any of the following change:

- top-level directories or module names
- canonical build commands
- app entry points or shared UI roots
- preferred read order for new sessions

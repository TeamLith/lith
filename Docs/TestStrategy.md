# Test Strategy

## Commands and evidence levels

- `scripts/validate.sh --package-only` regenerates the project, builds and runs the Swift package tests, and typechecks shared/macOS app sources against the macOS SDK. It supports standalone Apple Command Line Tools by locating their bundled Swift Testing framework. It does **not** build the iOS app, execute an app, test signing, or run XCTest UI automation.
- `scripts/validate.sh` requires full Xcode and additionally builds the macOS and iOS Simulator app targets with signing disabled. Release signing is validated separately by the release workflow.
- `python3 -m unittest discover -s Tests/Tooling -v` checks that project generation is idempotent and identical across differently named checkout directories, including paths with spaces.
- `scripts/validate.sh --ui-tests` additionally executes the macOS and iOS navigation suites. Set `LITH_IOS_TEST_DESTINATION` to an installed simulator, for example `platform=iOS Simulator,name=iPhone 16`. Find valid destinations using `xcodebuild -showdestinations -scheme LithiOS -project LithApps.xcodeproj`. The macOS runner needs an interactive logged-in desktop and permission to automate the app.
- Add `--log-dir PATH` to retain command output, and `--fail-on-generated-diff` in CI to reject stale committed project artifacts. `LITH_BUILD_JOBS` controls Swift package compilation parallelism (default 2).

## Primary flow matrix

| User journey / risk | Automated evidence | Remaining boundary |
| --- | --- | --- |
| Create/edit/archive/delete a note, resolve a wikilink, find it in search | `CriticalFlowTests.noteCRUDWikilinksAndSearchShareDurableState` uses real Core Data repositories, view models, and services | Device typing, VoiceOver, and keyboard interaction |
| Review an RSS article, require approval, save once, discover the resulting note | `CriticalFlowTests.approvedRSSArticleAppearsOnceInSearchWithSourceMetadata` exercises persisted workflow state and source metadata | Real feed network conditions and web content |
| Upgrade an existing local library | `CriticalFlowTests.legacySQLiteUpgradeRetainsNotesFeedsItemsAndLinks` creates an actual legacy SQLite store, closes it, opens it through the production migration settings, checks retained note/feed/article/link data, and writes new audio metadata | Signed-device upgrade from every previously distributed app build |
| Debounced note autosave | `NoteDetailViewModelTests.scheduleAutosavePersistsEdits` invokes the actual scheduler and waits for persisted state with a bounded deadline | App termination during an edit |
| Navigation shell, editor, RSS approval/detail, search, settings | `Apps/LithApp/UITests/CriticalNavigationTests.swift`, included in both app schemes | Execution requires full Xcode, a simulator, and a macOS desktop |
| Repository bootstrap | Existing `AppDependencyContainerTests` exercise in-memory startup and repository wiring | Store corruption, disk-full, protected-data/device-lock behavior |
| Disabled sync and cloud conflicts | Sync-engine integration tests use an injected transport and local Core Data | Signed, provisioned, multi-device CloudKit account changes and server behavior |
| Audio recording/transcription | Driver-backed service/view-model tests cover metadata, denial, failures, cancellation, recovery, and UI state | Actual microphones, interruptions, Speech language assets, permissions, and playback |
| Graph/search semantics | Existing parser, search, graph, and discovery view-model suites | Large-library performance and interactive layout |

The SQLite migration test deliberately omits newly added entities from its source model and does not bundle a source `.mom`. Additive migrations must retain the old records; it must never delete a store to make startup succeed. A separate manual process-restart probe also verified the legacy-to-audio upgrade in the standalone Command Line Tools environment.

## UI-test isolation

Both app targets accept `--ui-testing` only in Debug builds. The launch path creates an **in-memory** dependency container and seeds one note and a local RSS fixture before showing the navigation shell. The RSS URL uses `example.invalid`; tests do not refresh feeds, invoke microphone/Speech permissions, or enable cloud sync. Release builds ignore this argument. Every XCTest launches a fresh app instance and terminates it afterward.

UI test files and generated schemes are checked in, but their presence is not evidence that they passed. In an environment without full Xcode/XCTest and a simulator, report them as **not executed**, and do not substitute package tests or macOS source typechecking for an iOS/UI test result.

## Broader release gates

Retain checks for Markdown round trips, backlinks and metadata integrity; sync under offline/concurrent edits/rejoin; app restart and permission recovery; supported OS versions; Dynamic Type, VoiceOver, keyboard operation and Reduce Motion; and performance against the product's documented targets. Never contact production CloudKit or erase a user's library as part of an automated fixture. Signing, TestFlight upload, and production CloudKit schema verification require the release owner's configured accounts.

# Sync: iCloud / CloudKit

## Requirements

- App must work local-only when iCloud unavailable or disabled.
- If enabled, sync these entities via CloudKit:
  - Note, Tag, Link, RssFeed, RssItem, AudioNote metadata, ActionItem
- Conflict baseline:
  - last-writer-wins for automatic path
  - persist conflict history for later manual merge UX

## Task: CloudKit Schema

- Input specs:
  - `DATA_MODEL.md`
- Deliverables:
  - Record type mapping documentation and implementation
- Steps:
  - [ ] Map each sync entity to CloudKit record type.
  - [ ] Define field names and indexes.
  - [ ] Document migration strategy for field additions.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Sync Engine

- Input specs:
  - `ARCHITECTURE.md`
- Deliverables:
  - Incremental synchronization workflow
- Steps:
  - [ ] Implement sync adapter over `NSPersistentCloudKitContainer`.
  - [ ] Add pull/push cycle with retry/throttle handling.
  - [ ] Record sync status and recoverable errors.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: iCloud Settings UI

- Input specs:
  - `ARCHITECTURE.md`
- Deliverables:
  - Settings controls for sync behavior
- Steps:
  - [ ] Add iCloud enable/disable toggle.
  - [ ] Show status (`offline|syncing|synced|error`).
  - [ ] Show last successful sync timestamp.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

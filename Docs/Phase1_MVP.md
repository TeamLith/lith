# Phase 1 - MVP Foundation

## Scope

- Note CRUD with markdown body.
- Wiki linking and backlink data.
- Tags and baseline full-text search.
- iCloud-first sync strategy with explicit conflict policy.

## Implemented foundation

- `Note`, `Link`, `SearchFilter`, `SyncConflict` models.
- `InMemoryNoteRepository` + `InMemoryLinkRepository`.
- `WikiLinkParser`, `SearchService`, `ConflictResolver`.

## Next implementation steps

- Replace in-memory stores with Core Data repositories.
- Add `NSPersistentCloudKitContainer` adapter behind `CloudSyncAdapter`.
- Add conflict review UI path for manual merges.

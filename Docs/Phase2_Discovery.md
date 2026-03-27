# Phase 2 - Discovery

## Scope

- Advanced search filters and saved searches.
- Backlinks panel.
- Local and global graph views.
- macOS native parity for core note workflows.

## Implemented foundation

- `SavedSearch`, `GraphNode`, `GraphEdge`, `NoteGraph`, `GraphMode`.
- `GraphBuilder` with deterministic local neighborhood extraction and global graph payload generation.

## Next implementation steps

- Add persisted saved-search storage.
- Build SwiftUI graph renderer with LOD and pan/zoom controls.
- Introduce graph caching/indexing for large vaults.

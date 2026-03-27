# Feature: Text Notes

## Requirements

- Create, edit, delete text notes.
- Markdown editing first; preview can be incremental.
- Parse and resolve wikilinks `[[note title]]` into `Link` entities.
- Show basic note list with pin/sort/filter support.

## Task: Implement Note Repository

- Input specs:
  - `DATA_MODEL.md` (`Note`, `Tag`, `Link`)
- Deliverables:
  - Core Data entities/mappings
  - Repository API for CRUD and simple text lookup
  - Unit tests
- Steps:
  - [ ] Define `Note` entity and indexes.
  - [ ] Implement `NoteRepository` with CRUD.
  - [ ] Add simple title/body search (`CONTAINS[cd]`).
  - [ ] Add tests for create/update/delete/query.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Implement Note List and Detail UI

- Input specs:
  - `ARCHITECTURE.md`
  - `DATA_MODEL.md`
- Deliverables:
  - SwiftUI list and detail screens
- Steps:
  - [ ] Build list view sections (`Pinned`, `Recent`).
  - [ ] Build detail editor with markdown text editor.
  - [ ] Add preview stub toggle.
  - [ ] Wire screens to repository/service.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Implement Wikilink Parsing

- Input specs:
  - `DATA_MODEL.md` (`Link`)
- Deliverables:
  - Parser + linker + backlinks panel data
- Steps:
  - [ ] Parse `[[...]]` references from `bodyMarkdown`.
  - [ ] Resolve by title and upsert `Link` rows.
  - [ ] Expose backlink query for note detail UI.
  - [ ] Add parser/linking tests.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

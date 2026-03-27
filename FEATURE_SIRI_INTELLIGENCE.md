# Feature: Siri Intelligence

## Capabilities

1. Siri capture via App Intents/SiriKit
   - "Create note"
   - "Append to note"
   - "Start meeting recording"
2. Transcript action-item extraction
   - Heuristic parser for statements like "I will", "We need to", "TODO"
   - Save structured `ActionItem` records

## Task: Basic App Intent for Create Note

- Input specs:
  - `ARCHITECTURE.md`
  - `DATA_MODEL.md` (`Note`)
- Deliverables:
  - `CreateNoteIntent` wired to domain service
- Steps:
  - [ ] Define App Intent.
  - [ ] Map title/content params.
  - [ ] Wire to `NoteService` and return confirmation.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Transcript Action Item Extractor

- Input specs:
  - `DATA_MODEL.md` (`ActionItem`)
- Deliverables:
  - Extractor + test suite
- Steps:
  - [ ] Parse transcript into `ActionItemDraft` values.
  - [ ] Add heuristic/date parsing rules.
  - [ ] Add tests with canned transcript fixtures.
  - [ ] Persist accepted items as `ActionItem`.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Action Item UI

- Input specs:
  - `ARCHITECTURE.md`
- Deliverables:
  - Checklist UI under transcript
- Steps:
  - [ ] Render checklist tied to structured items.
  - [ ] Support mark-done, edit, delete.
  - [ ] Add review gate before reminders export.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

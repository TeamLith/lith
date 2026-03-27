# Master Roadmap (Phases 1-5)

## Locked decisions

- macOS delivery: native SwiftUI.
- Action items: structured model only.
- Sync scope: iCloud-only through Phase 5.
- Graph layout: deterministic local graph + bounded-force global graph.

## Delivery sequence

1. Phase 1: Notes foundation + sync reliability.
2. Phase 2: Discovery (advanced search + backlinks + graph).
3. Phase 3: RSS curation and conversion pipeline.
4. Phase 4: Audio recording and transcription.
5. Phase 5: Siri intents + transcript intelligence/action items.

## Exit gates

- Phase 1: reliable offline/online note integrity across devices.
- Phase 2: graph/search responsiveness on representative vault scale.
- Phase 3: deterministic RSS conversion with feed health handling.
- Phase 4: stable record-transcribe-review flow on-device.
- Phase 5: Siri intent correctness and action extraction review workflow.

## Public interfaces standardized in code

- `WikiLinkParser` for `[[Note Name]]` contract.
- `SearchServiceProtocol` and `SearchFilter`.
- `RSSConversionServiceProtocol` with canonical metadata mapping.
- `TranscriptionStatus` + `AudioRecording` lifecycle model.
- `ActionItem` (`task`, `assignee`, `dueDate`, `status`, `sourceNoteID`).
- `SiriIntentAdapter` surface (`createNote`, `appendToNote`).

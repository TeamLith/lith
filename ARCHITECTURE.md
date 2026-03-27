# Architecture

## High-level layers

- UI layer (SwiftUI)
  - Notes list/editor, feeds inbox, search, graph, settings
- Domain layer (services/use-cases)
  - `NoteService`, `RssService`, `AudioNoteService`, `SearchService`, `ActionItemService`, `SyncService`
- Data layer
  - Core Data repositories
  - CloudKit sync adapter
  - RSS parser adapter (FeedKit)

## Sync strategy

- Local-first Core Data is always authoritative for app responsiveness.
- CloudKit mirrors synced entities for iCloud-enabled users.
- Conflict baseline: last-writer-wins + retained conflict history for manual review UI later.

Reference pattern: Apple sample for Core Data + CloudKit sync.

## Audio and Siri strategy

- Audio capture: AVAudioRecorder / AVAudioEngine
- Transcription: Apple Speech framework (on device where supported)
- Siri/App Intents:
  - create note
  - append note
  - start meeting recording
  - retrieve action items

## Search and graph strategy

- Maintain link relationships via `Link` entity/table.
- Search through note content + tags + selected metadata fields.
- Graph layer uses in-memory node/edge projection from note/link data.
- Start simple: deterministic local graph and bounded-force global graph.

## Dependencies policy

Use only MIT or more permissive licenses. Every new dependency must include:

- license type
- reason for inclusion
- replacement/fallback note

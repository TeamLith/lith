# Phase 5 - Siri Intelligence

## Scope

- Siri voice intents for note creation, append, search, action review.
- Action-item extraction from transcripts with user review.
- Optional Reminders handoff after approval.

## Implemented foundation

- `ActionItem` model.
- `ActionItemExtractionService`.
- `SiriIntentAdapter` contract.

## Next implementation steps

- App Intents/SiriKit handlers wired to note services.
- On-device extraction quality evaluation harness.
- Reminder export adapter with explicit user confirmation.

# Test Strategy

## Contract and unit tests

- Wiki-link parsing and relationship generation.
- Query semantics (`AND`, `OR`, `NOT`) for search.
- RSS conversion metadata integrity.
- Graph builder local/global correctness.
- Conflict policy behavior.
- Transcript action item extraction and due date normalization.

## Phase-gate suites

- Sync correctness under offline, concurrent edits, and rejoin.
- Data integrity (markdown round-trip, backlinks, metadata persistence).
- Performance checks against PRD thresholds.
- Security/privacy checks (permission paths, no external telemetry).
- Accessibility checks (Dynamic Type, VoiceOver, keyboard flows, reduce motion).

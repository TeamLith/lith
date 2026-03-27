# Feature: RSS Inbox

## Requirements

- Add feed URL.
- Fetch and store items in `RssItem`.
- Inbox UI grouped by feed/category.
- Manual approval flow: item -> Save as Note.
- No automatic item-to-note conversion.

## Implementation notes

- Use FeedKit (MIT) behind adapter boundary.
- Start with manual refresh; background scheduling is follow-up.

## Task: RSS Data Layer

- Input specs:
  - `DATA_MODEL.md` (`RssFeed`, `RssItem`)
- Deliverables:
  - Core Data schema + repository methods
- Steps:
  - [ ] Implement feed/item entities.
  - [ ] Add methods: add/list feeds, update `lastFetchedAt`, upsert items.
  - [ ] Add parser-to-entity mapping tests.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: RSS Fetcher

- Input specs:
  - `ARCHITECTURE.md`
- Deliverables:
  - Feed fetch service + error handling
- Steps:
  - [ ] Wrap FeedKit in `RssFetcher` service.
  - [ ] Implement manual refresh action.
  - [ ] Add structured error logging/retry policy.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: RSS Inbox UI

- Input specs:
  - `ARCHITECTURE.md`
- Deliverables:
  - SwiftUI inbox + approve flow
- Steps:
  - [ ] Build feed/item list UI.
  - [ ] Add `Approve -> Save as Note` action.
  - [ ] Persist source metadata + source link relationship.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

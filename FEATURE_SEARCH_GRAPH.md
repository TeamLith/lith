# Feature: Search and Graph

## Requirements

- Full-text search across note title/body/tags and selected metadata.
- Filters: source (`manual|rss|audio`), date range, optional tags.
- Graph:
  - Nodes = notes
  - Edges = link relationships

## Implementation strategy

- Start with Core Data predicate-based search.
- Build in-memory graph projection from note/link entities.
- Use simple graph layout first; optimize later.

## Task: Search API

- Input specs:
  - `DATA_MODEL.md`
- Deliverables:
  - Unified search entry point
- Steps:
  - [ ] Implement `search(query:filters:)`.
  - [ ] Query title/body/tags/metadata/transcript fields.
  - [ ] Add matching tests for all scopes.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Search UI

- Input specs:
  - `ARCHITECTURE.md`
- Deliverables:
  - Search screen and result navigation
- Steps:
  - [ ] Build search bar + filter chips.
  - [ ] Render result list with snippets.
  - [ ] Navigate to note detail.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Graph Data Builder

- Input specs:
  - `DATA_MODEL.md` (`Note`, `Link`)
- Deliverables:
  - Node/edge projection API
- Steps:
  - [ ] Build in-memory graph from notes + links.
  - [ ] Return typed node/edge structs.
  - [ ] Add local-graph depth filtering.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Graph View

- Input specs:
  - `ARCHITECTURE.md`
- Deliverables:
  - Interactive graph screen
- Steps:
  - [ ] Render nodes/edges with simple layout.
  - [ ] Support pan/zoom.
  - [ ] Tap node to open note.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

# Phase 3 - RSS Curation

## Scope

- Feed management and refresh.
- Item inbox with approve-to-save flow.
- Metadata-preserving note conversion and backlinks.

## Implemented foundation

- `RSSFeed`, `RSSItem`, `RSSItemStatus`.
- `RSSConversionService` for canonical note conversion.

## Next implementation steps

- Add parser adapter (FeedKit) behind fetcher service.
- Persist feed health and refresh state.
- Wire conversion flow into note repository + link repository.

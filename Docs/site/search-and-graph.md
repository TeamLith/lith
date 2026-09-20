---
title: Search and Graph
nav_order: 6
---

# Search and Graph

Lith is meant to make stored knowledge easier to find, revisit, and connect.

## Search

Open **Search & Graph** and type in the search field. Results include the title, a body snippet, source, last-updated date, and tags. Select a result to read or edit the note; results refresh after you return.

- Leave the query empty to browse all active notes, newest updated first. Archived and trashed notes are excluded.
- Choose a source: Manual, RSS, Audio, or All sources.
- Enter comma-separated tags to match notes with any of those tags.
- Turn on the date filter to include notes updated from the selected start day through the end day, in your current time zone.
- Use **Clear search and filters** to start again.

Search matches titles, body text, tags, and stored metadata. Basic `AND`, `OR`, and `NOT` expressions are supported. A failed search shows a retry button. An invalid date range shows an explanation instead of running the search.

## Graph

Graph data is built from your saved notes and links. Global mode includes all active notes, including unlinked notes. Local mode starts from one note and follows both incoming and outgoing links up to the selected number of hops. Zero hops includes only the selected note. Archived and trashed notes are excluded, along with links to missing or hidden notes.

From Search, select **Graph** in the toolbar to explore your notes on a stable circular layout. Select a node to open its note. Drag the graph to pan, pinch to zoom, or use the zoom buttons. **Reset view** restores the initial position and zoom.

Choose a note in the Graph picker for local mode, then adjust **Link depth** (0–5). Choose **All notes** to return to the global graph. The center is highlighted. Changing the mode resets the viewport. Returning from a note refreshes the graph.

Turn on **Show accessible note list** for a linear list of notes and link counts, with the same note navigation. Nodes also have VoiceOver labels. The graph uses no automatic motion or layout animations, including when Reduce Motion is enabled.

## Availability

Search and graph run locally on your stored notes. Graph edges represent saved links; arrows are not shown in the visual layout.

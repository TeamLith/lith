---
title: RSS Inbox
nav_order: 4
---

# RSS Inbox

Add feeds and review articles before saving them to your note library. Refreshing or approving an article never automatically creates a note.

## Add and refresh feeds

1. Open **RSS Inbox** and choose **Add Feed**.
2. Enter a complete HTTP or HTTPS RSS, Atom, or JSON Feed URL. Add an optional title and category to organize it.
3. Choose **Add**, then **Refresh Feeds** to fetch articles. Refresh is manual; Lith does not refresh in the background.

Articles are grouped by category and feed. Adding the same feed URL again keeps its existing configuration. Individual feed failures appear in the inbox so you can retry with **Refresh Feeds** while continuing to read articles already downloaded.

## Review and save

The inbox initially shows **New** articles. Use **Show articles** to view approved, ignored, saved, or all articles.

Open an article to read its downloaded content or choose **Read Original Article** to open its source in your browser. Choose **Approve** to mark it for saving, then optionally add commentary and choose **Save as Note**. The note opens for reading and editing and also appears in Notes.

Saved notes include the article's source URL, author and publication date when supplied, feed title/category, and an RSS tag. Lith retains the relationship between the inbox article and its note. Repeating a save or retrying after an interrupted save reuses that note instead of creating a duplicate or replacing your edits. A saved article offers **Open Saved Note**.

Choose **Ignore** to set an article aside, or **Mark New** to return an ignored or approved article to the new list. Refresh preserves these decisions. Saved articles keep their saved state; manage the note from Notes.

If a save fails, the error stays visible and you can retry. Article content is displayed as downloaded text; HTML markup supplied by a feed may be visible. No article is converted to a note without your explicit save action.

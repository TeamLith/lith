---
title: Notes and Links
nav_order: 3
---

# Notes and Links

Lith starts with fast text notes that stay readable, portable, and easy to connect.

## Notes

Create a note with **New Note**. On iPhone and iPad, it opens directly in the editor; existing notes open in the reading view, where **Edit** lets you write Markdown. The reading view renders headings, paragraphs, bulleted and numbered lists, quotes, fenced code, and inline formatting. Code blocks keep their literal text. Other Markdown remains readable as text; this is a basic preview rather than a full publishing renderer.

## Organize and recover notes

Use the **Notes**, **Archive**, and **Trash** picker above the list. Pinned notes appear first in each collection.

- **Archive** hides a note from the active list without deleting it.
- **Move to Trash** keeps a recoverable copy in Trash.
- In Archive or Trash, use **Restore** from the note’s menu (or swipe actions on iPhone/iPad) to return it to Notes. Its content, tags, source metadata, pin, and creation date remain intact.
- **Delete Permanently** is available only in Trash and asks for confirmation. It removes the note, associated actions, links, recording metadata, and local audio files. Active recording and transcription work is stopped before deletion. It cannot be undone.

## Import and export Markdown

Choose **Import Markdown** in the note-list toolbar, then select a UTF-8 `.md` or text file in the system file picker. Every import creates and opens a new note, even if the title matches an existing note. A top-level Markdown heading supplies the title when available; otherwise the filename does. Imported wikilinks are resolved against saved notes.

In a note, choose **Actions → Export Markdown** and select a destination in the system save dialog. Export includes the current title and exact Markdown body. Lith stores the title as standard front matter, so reimporting its export restores the title and body. Tags, app flags, source metadata, audio files, and structured action records are not part of the Markdown file.

Existing files are handled by the native save dialog, including its overwrite confirmation.

Edits are flushed when you leave the note or background the app. If another window or sync changed/deleted the note, Lith keeps your unsaved text visible and reports a conflict instead of restoring deleted content or silently overwriting the other change. Copy the unsaved text, then reopen the note to reconcile it.

## Wikilinks and backlinks

- Connect notes using `[[wikilinks]]`.
- Use backlinks to rediscover related notes. Markdown imports and Siri-created or appended notes update these links too. Creating or renaming a target rechecks earlier links to its title; archiving, trashing, and restoring notes refresh their visible connections.
- Let links turn isolated notes into a connected knowledge graph over time.

## Best fit

This workflow is designed for people who want quick capture first and deeper organization second, without forcing a heavy structure at the moment a note is created.

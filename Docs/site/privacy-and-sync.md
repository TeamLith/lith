---
title: Privacy and Sync
nav_order: 7
---

# Privacy and Sync

Lith is built around local ownership of your data.

## Local-first

- Local storage stays authoritative for responsiveness.
- The product is grounded in portable, Markdown-friendly note workflows instead of service lock-in.

## Sync

- Sync is off by default. Your notes remain usable without an iCloud account, network connection, or configured CloudKit container.
- A configured build can mirror notes (including tags), links, RSS feeds/articles, audio metadata, and accepted action records to your private iCloud database. No public or shared CloudKit database is used. Settings controls are supplied separately from the sync engine.
- Sync pulls changes before uploading local edits. Deletions are retained as cloud tombstones so offline devices learn about them. Failed or interrupted runs can be retried.
- For records with reliable edit timestamps, the newer edit wins and both conflicting copies are retained. Older RSS records and concurrent deletions without a trustworthy edit time require an explicit local/cloud choice. If another device changes an item during an upload, sync stops with an error and keeps both copies instead of blindly overwriting it.
- iCloud can ask Lith to wait before retrying. Longer retry deadlines are retained across app restarts. Errors never require deleting your local library.
- Switching iCloud accounts pauses sync to prevent mixing private libraries. Sign back into the original account to resume; Lith does not silently upload the previous account's local data to a new account.
- A deleted feed never silently removes unsynced articles. If local articles remain, retain the local feed when resolving the conflict to preserve and sync them.
- Audio sync currently includes metadata and transcript only. Recording files remain on the device where they were captured; cross-device playback requires a future audio-file transfer provider.

The release owner must configure the app's Apple-owned CloudKit container and capabilities before a build can enable live sync. An unconfigured build remains local-only. Live, signed multi-device sync still needs verification with that account configuration.

## Platform boundaries

- Lith targets iPhone, iPad, and macOS.
- Web and Android parity are not first-release goals.

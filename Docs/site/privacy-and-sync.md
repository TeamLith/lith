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
- A configured build can mirror notes (including tags), links, RSS feeds/articles, audio metadata, and accepted action records to your private iCloud database. No public or shared CloudKit database is used. Open **Settings → Enable iCloud Sync** to opt in. If the build lacks its iCloud configuration, the toggle stays unavailable and Settings explains why.
- Sync pulls changes before uploading local edits. Deletions are retained as cloud tombstones so offline devices learn about them. Failed or interrupted runs can be retried.
- For records with reliable edit timestamps, the newer edit wins and both conflicting copies are retained. Older RSS records and concurrent deletions without a trustworthy edit time require an explicit local/cloud choice. If another device changes an item during an upload, sync stops with an error and keeps both copies instead of blindly overwriting it.
- iCloud can ask Lith to wait before retrying. Longer retry deadlines are retained across app restarts. Errors never require deleting your local library.
- Switching iCloud accounts pauses sync to prevent mixing private libraries. Sign back into the original account to resume; Lith does not silently upload the previous account's local data to a new account.
- A deleted feed never silently removes unsynced articles. If local articles remain, retain the local feed when resolving the conflict to preserve and sync them.
- A deleted note is retained for review while local recordings, actions, or links still depend on it. Child deletions are processed first; unsynced children are kept locally until you keep the parent or remove those children. An incoming deletion that conflicts with a local edit always requires an explicit choice.
- Audio sync currently includes metadata and transcript only. Recording files remain on the device where they were captured; cross-device playback requires a future audio-file transfer provider.
- Accepting a recording deletion removes its local audio file after metadata is safely deleted. Interrupted file cleanup resumes on the next sync. Active recordings and transcription jobs are retained for review until that work finishes.

The release owner must configure the app's Apple-owned CloudKit container and capabilities before a build can enable live sync. An unconfigured build remains local-only. Live, signed multi-device sync still needs verification with that account configuration.


## Settings and automatic sync

Use **Settings** to enable or disable iCloud, inspect the status and last successful sync, or choose **Sync Now** / **Retry Sync**. The preference persists across launches. Disabling sync retains both your local library and existing iCloud records.

When enabled, Lith syncs when a window becomes active and every **60 seconds** while at least one window remains active. Backgrounding every window cancels the periodic task and stops further requests; a request already submitted may finish. Local edits are included in the next cycle, or immediately when you choose **Sync Now**. This build does not schedule background refresh or receive push notifications for sync.

Settings also shows a server-requested retry deadline. Waiting until that time avoids repeatedly contacting a throttled service. If you change iCloud accounts, sign back into the original account before retrying; account boundaries are not reset automatically.

Under **Retained Conflicts**, expand an item to read both versions. Unresolved conflicts offer **Keep Local Version** and **Use Cloud Version**; choose explicitly, then use **Sync Now**. Both historical copies remain available. A cloud deletion of a feed cannot be accepted while local articles still depend on it; keeping the local feed preserves them. If you edited an item during review, sync again to refresh its retained local version before choosing.

The same protection applies to notes with recordings, actions, or links. Choose **Keep Local Version** to preserve the note and sync its children. To accept deletion, remove the dependent records first. Retained conflict history contains audio metadata and transcripts; choosing to delete a recording also deletes its device-local audio file.

## Platform boundaries

- Lith targets iPhone, iPad, and macOS.
- Web and Android parity are not first-release goals.

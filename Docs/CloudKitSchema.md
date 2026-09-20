# CloudKit schema v1

Lith keeps its existing SQLite/Core Data store and mirrors domain records through a CloudKit adapter into the user's **private** database, custom zone `LithPrivateV1`. No shared/public database is used. This avoids changing existing Core Data uniqueness constraints or replacing a user's local store.

| Domain | Record type | Payload |
| --- | --- | --- |
| Note | LithNote | Note JSON, including sorted tags and metadata |
| Tag | LithTag | Reserved for future independent tag records; currently tags travel atomically inside their note |
| Link | LithLink | Link JSON with source/target UUID and creation time |
| RSSFeed | LithRSSFeed | Feed JSON including URL and refresh state |
| RSSItem | LithRSSItem | Item JSON including approval state and saved note UUID |
| AudioRecording | LithAudioRecording | Recording JSON containing relative file identity, transcript and lifecycle state; audio binary is a separate file |
| ActionItem | LithActionItem | Accepted action JSON, including source note, assignee, date and status |

All record types use `entityID` (String UUID), `schemaVersion` (Int64, currently 1), `modifiedAt` (Date), `deleted` (Int64 boolean), and `payload` (Bytes containing Codable JSON). Record names are `<record type>:<lowercase UUID>`. A tombstone keeps identity/time but clears payload. Never immediately purge tombstones: an offline device must be able to learn about deletions.

The sync adapter fetches custom-zone changes using server change tokens, so no query indexes are required. `recordName` is the primary identity. If adding a dashboard query later, add the corresponding queryable/sortable index before deploying that query. Payloads exceeding 750 KB are rejected visibly without deleting the local record.

Conflict ordering uses modifiedAt; the adapter must preserve the losing local/remote payload for later review. Server change tags must be retained and saves use `ifServerRecordUnchanged` so an intervening write is never blindly overwritten. CloudKit zone tokens and baselines belong to a single iCloud account.

Migration is additive: new optional Codable fields require backward-compatible defaults; never rename a deployed record type or reuse a field with a different type. A future incompatible format must increment schemaVersion and supply a migration. Older clients reject future versions before applying them. Keep local database lightweight migration enabled. Test old-store startup and record round trips before shipping.

A release owner must configure an Apple-owned CloudKit container, enable iCloud capabilities for both app IDs, and deploy the development schema to production through CloudKit Console before a TestFlight release. These signing and account steps are not performed by the schema code.

References: [CloudKit save policies](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/savepolicy), [record zone changes](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation).

## Sync engine integration

Use one `SyncEngine` per persistent store, with `CoreDataSyncStore`, `AppleCloudKitTransport(containerIdentifier:)`, and `FileSyncStatePersistence` under the app's Application Support directory. No default container identifier is assumed. `restoreStatus()` reads the last successful timestamp, conflicts, and retry deadline without contacting iCloud; `setEnabled(true)` is the explicit opt-in before `synchronize()`.

The checkpoint stores the account record ID, incremental change token, acknowledged record baselines/system fields, pending change clocks, full conflict copies, and retry deadline. It is written atomically. Never reuse its URL for a different local library. Account changes block synchronization; do not discard this guard or automatically reset the checkpoint on sign-in changes.

The local bridge compares the current payload against its fetched snapshot, then saves with an error merge policy to reject concurrent local changes. Ordinary repository contexts merge remote saves automatically. Note edit timestamps are authoritative. Legacy entities without modification timestamps get a clock when the engine first detects a changed payload; unchanged payloads retain their acknowledged baseline clock. Local hard deletions similarly acquire their tombstone clock on detection.

Cloud uploads retain system fields and use `ifServerRecordUnchanged`. Three attempts are allowed for transient failures; server throttle delays over a minute become a persisted deadline for a later user-triggered run. Expired tokens clear only the cursor, retaining baselines and conflict history for a safe full pull. Physical CloudKit record deletion (outside Lith's tombstone protocol) stops with an error rather than guessing a deletion timestamp. Unsupported entity/schema versions and uniqueness collisions stop visibly without replacing local data.

Audio and action entities are discovered dynamically after their additive Core Data schemas are installed. They use UUID identity and portable JSON payloads; audio binaries are not uploaded by this metadata engine. Missing parent feeds are reported, and feed/item ordering is resolved across fetched pages before applying changes.

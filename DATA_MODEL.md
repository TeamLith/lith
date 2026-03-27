# Data Model

All entities are Core Data backed. IDs are UUID unless noted.

## Note

- Fields:
  - `id: UUID`
  - `title: String`
  - `bodyMarkdown: String`
  - `createdAt: Date`
  - `updatedAt: Date`
  - `accessedAt: Date?`
  - `isPinned: Bool`
  - `isArchived: Bool`
  - `isTrashed: Bool`
  - `source: String` (`manual|rss|audio`)
- Relationships:
  - to-many `tags`
  - to-many outgoing `linksFrom`
  - to-many incoming `linksTo`
  - to-many `audioNotes`
  - to-many `actionItems`
- CloudKit sync: Yes

## Tag

- Fields:
  - `id: UUID`
  - `name: String` (normalized lowercase key)
- Relationships:
  - to-many `notes`
- CloudKit sync: Yes

## Link

- Fields:
  - `id: UUID`
  - `fromNoteId: UUID`
  - `toNoteId: UUID`
  - `linkType: String` (`wikilink|manual|rssSource`)
  - `createdAt: Date`
- Relationships:
  - to-one `fromNote`
  - to-one `toNote`
- CloudKit sync: Yes

## RssFeed

- Fields:
  - `id: UUID`
  - `url: URL`
  - `title: String`
  - `category: String?`
  - `lastFetchedAt: Date?`
  - `isActive: Bool`
  - `refreshIntervalSeconds: Int32`
- Relationships:
  - to-many `items`
- CloudKit sync: Yes

## RssItem

- Fields:
  - `id: UUID`
  - `feedId: UUID`
  - `title: String`
  - `content: String`
  - `author: String?`
  - `linkUrl: URL`
  - `publishedAt: Date?`
  - `status: String` (`new|approved|ignored|savedAsNote`)
  - `savedNoteId: UUID?`
- Relationships:
  - to-one `feed`
- CloudKit sync: Yes

## AudioNote

- Fields:
  - `id: UUID`
  - `noteId: UUID`
  - `audioFileUrl: URL`
  - `durationSeconds: Double`
  - `transcript: String?`
  - `transcriptionStatus: String` (`notStarted|processing|complete|failed`)
  - `recordedAt: Date`
- Relationships:
  - to-one `note`
- CloudKit sync: Metadata yes; binary file path points to iCloud/local file store

## ActionItem

- Fields:
  - `id: UUID`
  - `noteId: UUID`
  - `descriptionText: String`
  - `dueDate: Date?`
  - `assigneeText: String?`
  - `status: String` (`open|done|dropped`)
  - `createdAt: Date`
  - `updatedAt: Date`
- Relationships:
  - to-one `note`
- CloudKit sync: Yes

import Foundation

public actor InMemoryNoteRepository: NoteRepository {
    private var notes: [UUID: Note] = [:]

    public init(seed: [Note] = []) {
        for note in seed {
            notes[note.id] = note
        }
    }

    public func upsert(_ note: Note) async throws {
        notes[note.id] = note
    }

    public func delete(noteID: UUID) async throws {
        notes.removeValue(forKey: noteID)
    }

    public func allNotes() async throws -> [Note] {
        notes.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func note(id: UUID) async throws -> Note? {
        notes[id]
    }
}

public actor InMemoryLinkRepository: LinkRepository {
    private var graph: [UUID: [Link]] = [:]

    public init() {}

    public func replaceLinks(from sourceNoteID: UUID, with links: [Link]) async throws {
        graph[sourceNoteID] = links
    }

    public func links() async throws -> [Link] {
        graph.values.flatMap { $0 }
    }
}

public actor InMemoryRSSRepository: RSSRepository {
    private var feedsByID: [UUID: RSSFeed] = [:]
    private var feedIDsByURL: [String: UUID] = [:]
    private var itemsByID: [UUID: RSSItem] = [:]
    private var itemIDsByCompositeKey: [RSSItemCompositeKey: UUID] = [:]

    public init(seedFeeds: [RSSFeed] = [], seedItems: [RSSItem] = []) {
        for feed in seedFeeds {
            feedsByID[feed.id] = feed
            feedIDsByURL[normalizedURL(feed.feedURL)] = feed.id
        }
        for item in seedItems {
            itemsByID[item.id] = item
            itemIDsByCompositeKey[RSSItemCompositeKey(feedID: item.feedID, linkURL: normalizedURL(item.linkURL))] = item.id
        }
    }

    public func addFeed(_ feed: RSSFeed) async throws {
        let urlKey = normalizedURL(feed.feedURL)

        if let existingID = feedIDsByURL[urlKey], let existing = feedsByID[existingID] {
            storeFeed(mergedFeed(existing: existing, incoming: feed))
            return
        }

        storeFeed(feed)
    }

    public func feeds() async throws -> [RSSFeed] {
        feedsByID.values.sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    public func feed(id: UUID) async throws -> RSSFeed? {
        feedsByID[id]
    }

    public func updateLastFetchedAt(for feedID: UUID, to date: Date?) async throws {
        guard let existing = feedsByID[feedID] else {
            return
        }

        storeFeed(
            RSSFeed(
                id: existing.id,
                title: existing.title,
                feedURL: existing.feedURL,
                category: existing.category,
                lastFetchedAt: date,
                isActive: existing.isActive,
                refreshIntervalSeconds: existing.refreshIntervalSeconds
            )
        )
    }

    public func upsertItems(_ items: [RSSItem]) async throws {
        for item in items {
            let key = RSSItemCompositeKey(feedID: item.feedID, linkURL: normalizedURL(item.linkURL))

            if let existingID = itemIDsByCompositeKey[key], let existing = itemsByID[existingID] {
                storeItem(mergedItem(existing: existing, incoming: item))
                continue
            }

            storeItem(item)
        }
    }

    public func items(feedID: UUID? = nil) async throws -> [RSSItem] {
        itemsByID.values
            .filter { feedID == nil || $0.feedID == feedID }
            .sorted(by: rssItemSort)
    }

    public func item(id: UUID) async throws -> RSSItem? {
        itemsByID[id]
    }

    private func storeFeed(_ feed: RSSFeed) {
        feedsByID[feed.id] = feed
        feedIDsByURL[normalizedURL(feed.feedURL)] = feed.id
    }

    private func storeItem(_ item: RSSItem) {
        itemsByID[item.id] = item
        itemIDsByCompositeKey[RSSItemCompositeKey(feedID: item.feedID, linkURL: normalizedURL(item.linkURL))] = item.id
    }
}

private struct RSSItemCompositeKey: Hashable {
    let feedID: UUID
    let linkURL: String
}

func normalizedURL(_ url: URL) -> String {
    url.absoluteString
}

func mergedFeed(existing: RSSFeed, incoming: RSSFeed) -> RSSFeed {
    RSSFeed(
        id: existing.id,
        title: incoming.title,
        feedURL: incoming.feedURL,
        category: incoming.category,
        lastFetchedAt: incoming.lastFetchedAt ?? existing.lastFetchedAt,
        isActive: incoming.isActive,
        refreshIntervalSeconds: incoming.refreshIntervalSeconds
    )
}

func mergedItem(existing: RSSItem, incoming: RSSItem) -> RSSItem {
    let shouldPreserveWorkflowState = incoming.status == .new && incoming.savedNoteID == nil

    return RSSItem(
        id: existing.id,
        feedID: existing.feedID,
        title: incoming.title,
        content: incoming.content,
        author: incoming.author,
        publishedAt: incoming.publishedAt,
        linkURL: incoming.linkURL,
        status: shouldPreserveWorkflowState ? existing.status : incoming.status,
        savedNoteID: shouldPreserveWorkflowState ? existing.savedNoteID : incoming.savedNoteID
    )
}

func rssItemSort(lhs: RSSItem, rhs: RSSItem) -> Bool {
    switch (lhs.publishedAt, rhs.publishedAt) {
    case let (left?, right?) where left != right:
        return left > right
    case (_?, nil):
        return true
    case (nil, _?):
        return false
    default:
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

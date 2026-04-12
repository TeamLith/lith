import Foundation

public enum NoteSource: String, Codable, Sendable {
    case manual
    case rss
    case audio
}

public struct Note: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var bodyMarkdown: String
    public var tags: Set<String>
    public var createdAt: Date
    public var updatedAt: Date
    public var accessedAt: Date?
    public var source: NoteSource
    public var isPinned: Bool
    public var isArchived: Bool
    public var isTrashed: Bool
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        title: String,
        bodyMarkdown: String,
        tags: Set<String> = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        accessedAt: Date? = nil,
        source: NoteSource = .manual,
        isPinned: Bool = false,
        isArchived: Bool = false,
        isTrashed: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.accessedAt = accessedAt
        self.source = source
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.isTrashed = isTrashed
        self.metadata = metadata
    }
}

extension Note {
    private enum CodingKeys: String, CodingKey {
        case id, title, bodyMarkdown, tags, createdAt, updatedAt, accessedAt, source, isPinned, isArchived, isTrashed, metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        bodyMarkdown = try container.decode(String.self, forKey: .bodyMarkdown)
        tags = try container.decodeIfPresent(Set<String>.self, forKey: .tags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        accessedAt = try container.decodeIfPresent(Date.self, forKey: .accessedAt)
        source = try container.decodeIfPresent(NoteSource.self, forKey: .source) ?? .manual
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isTrashed = try container.decodeIfPresent(Bool.self, forKey: .isTrashed) ?? false
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }
}

public enum LinkType: String, Codable, Sendable {
    case wikilink
    case rssSource
    case manual
}

public struct Link: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let fromNoteID: UUID
    public let toNoteID: UUID
    public let type: LinkType

    public init(id: UUID = UUID(), fromNoteID: UUID, toNoteID: UUID, type: LinkType) {
        self.id = id
        self.fromNoteID = fromNoteID
        self.toNoteID = toNoteID
        self.type = type
    }
}

public struct RSSFeed: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var feedURL: URL
    public var category: String?
    public var lastFetchedAt: Date?
    public var isActive: Bool
    public var refreshIntervalSeconds: Int32

    public init(
        id: UUID = UUID(),
        title: String,
        feedURL: URL,
        category: String? = nil,
        lastFetchedAt: Date? = nil,
        isActive: Bool = true,
        refreshIntervalSeconds: Int32 = 3_600
    ) {
        self.id = id
        self.title = title
        self.feedURL = feedURL
        self.category = category
        self.lastFetchedAt = lastFetchedAt
        self.isActive = isActive
        self.refreshIntervalSeconds = refreshIntervalSeconds
    }
}

public enum RSSItemStatus: String, Codable, Sendable {
    case new
    case approved
    case ignored
    case savedAsNote
}

public struct RSSItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let feedID: UUID
    public var title: String
    public var content: String
    public var author: String?
    public var publishedAt: Date?
    public var linkURL: URL
    public var status: RSSItemStatus
    public var savedNoteID: UUID?

    public init(
        id: UUID = UUID(),
        feedID: UUID,
        title: String,
        content: String,
        author: String? = nil,
        publishedAt: Date? = nil,
        linkURL: URL,
        status: RSSItemStatus = .new,
        savedNoteID: UUID? = nil
    ) {
        self.id = id
        self.feedID = feedID
        self.title = title
        self.content = content
        self.author = author
        self.publishedAt = publishedAt
        self.linkURL = linkURL
        self.status = status
        self.savedNoteID = savedNoteID
    }
}

public struct ParsedRSSFeed: Hashable, Sendable {
    public var title: String
    public var feedURL: URL
    public var category: String?

    public init(title: String, feedURL: URL, category: String? = nil) {
        self.title = title
        self.feedURL = feedURL
        self.category = category
    }
}

public struct ParsedRSSItem: Hashable, Sendable {
    public var title: String
    public var content: String
    public var author: String?
    public var publishedAt: Date?
    public var linkURL: URL

    public init(
        title: String,
        content: String,
        author: String? = nil,
        publishedAt: Date? = nil,
        linkURL: URL
    ) {
        self.title = title
        self.content = content
        self.author = author
        self.publishedAt = publishedAt
        self.linkURL = linkURL
    }
}

extension RSSFeed {
    public init(
        parsedFeed: ParsedRSSFeed,
        id: UUID = UUID(),
        lastFetchedAt: Date? = nil,
        isActive: Bool = true,
        refreshIntervalSeconds: Int32 = 3_600
    ) {
        self.init(
            id: id,
            title: parsedFeed.title,
            feedURL: parsedFeed.feedURL,
            category: parsedFeed.category,
            lastFetchedAt: lastFetchedAt,
            isActive: isActive,
            refreshIntervalSeconds: refreshIntervalSeconds
        )
    }
}

extension RSSItem {
    public init(
        parsedItem: ParsedRSSItem,
        feedID: UUID,
        id: UUID = UUID(),
        status: RSSItemStatus = .new,
        savedNoteID: UUID? = nil
    ) {
        self.init(
            id: id,
            feedID: feedID,
            title: parsedItem.title,
            content: parsedItem.content,
            author: parsedItem.author,
            publishedAt: parsedItem.publishedAt,
            linkURL: parsedItem.linkURL,
            status: status,
            savedNoteID: savedNoteID
        )
    }
}

public enum TranscriptionStatus: String, Codable, Sendable {
    case notStarted
    case processing
    case complete
    case failed
}

public struct AudioRecording: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let noteID: UUID
    public var fileURL: URL
    public var duration: TimeInterval
    public var transcript: String
    public var status: TranscriptionStatus

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        fileURL: URL,
        duration: TimeInterval = 0,
        transcript: String = "",
        status: TranscriptionStatus = .notStarted
    ) {
        self.id = id
        self.noteID = noteID
        self.fileURL = fileURL
        self.duration = duration
        self.transcript = transcript
        self.status = status
    }
}

public enum ActionItemStatus: String, Codable, Sendable {
    case open
    case done
    case dropped
}

public struct ActionItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let sourceNoteID: UUID
    public var task: String
    public var assignee: String?
    public var dueDate: Date?
    public var status: ActionItemStatus

    public init(
        id: UUID = UUID(),
        sourceNoteID: UUID,
        task: String,
        assignee: String? = nil,
        dueDate: Date? = nil,
        status: ActionItemStatus = .open
    ) {
        self.id = id
        self.sourceNoteID = sourceNoteID
        self.task = task
        self.assignee = assignee
        self.dueDate = dueDate
        self.status = status
    }
}

public struct SavedSearch: Codable, Hashable, Sendable {
    public var name: String
    public var query: String
    public var filter: SearchFilter

    public init(name: String, query: String, filter: SearchFilter) {
        self.name = name
        self.query = query
        self.filter = filter
    }
}

public struct SearchFilter: Codable, Hashable, Sendable {
    public var sources: Set<NoteSource>
    public var tags: Set<String>
    public var dateRange: ClosedRange<Date>?

    public init(sources: Set<NoteSource> = Set(NoteSource.allCases), tags: Set<String> = [], dateRange: ClosedRange<Date>? = nil) {
        self.sources = sources
        self.tags = tags
        self.dateRange = dateRange
    }
}

extension NoteSource: CaseIterable {}

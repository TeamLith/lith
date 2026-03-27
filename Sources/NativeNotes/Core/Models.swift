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
    public var source: NoteSource
    public var isPinned: Bool
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        title: String,
        bodyMarkdown: String,
        tags: Set<String> = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: NoteSource = .manual,
        isPinned: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.isPinned = isPinned
        self.metadata = metadata
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

    public init(id: UUID = UUID(), title: String, feedURL: URL, category: String? = nil, lastFetchedAt: Date? = nil, isActive: Bool = true) {
        self.id = id
        self.title = title
        self.feedURL = feedURL
        self.category = category
        self.lastFetchedAt = lastFetchedAt
        self.isActive = isActive
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

    public init(
        id: UUID = UUID(),
        feedID: UUID,
        title: String,
        content: String,
        author: String? = nil,
        publishedAt: Date? = nil,
        linkURL: URL,
        status: RSSItemStatus = .new
    ) {
        self.id = id
        self.feedID = feedID
        self.title = title
        self.content = content
        self.author = author
        self.publishedAt = publishedAt
        self.linkURL = linkURL
        self.status = status
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

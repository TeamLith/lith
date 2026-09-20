import Foundation

public protocol NoteRepository: Sendable {
    func upsert(_ note: Note) async throws
    func updateExisting(_ note: Note, expected: Note) async throws
    func delete(noteID: UUID) async throws
    func allNotes() async throws -> [Note]
    func note(id: UUID) async throws -> Note?
}

public protocol LinkRepository: Sendable {
    func replaceLinks(from sourceNoteID: UUID, with links: [Link]) async throws
    func links() async throws -> [Link]
    func links(from sourceNoteID: UUID) async throws -> [Link]
    func backlinks(to targetNoteID: UUID) async throws -> [Link]
}

public protocol RSSRepository: Sendable {
    func addFeed(_ feed: RSSFeed) async throws
    func feeds() async throws -> [RSSFeed]
    func feed(id: UUID) async throws -> RSSFeed?
    func updateLastFetchedAt(for feedID: UUID, to date: Date?) async throws
    func upsertItems(_ items: [RSSItem]) async throws
    func items(feedID: UUID?) async throws -> [RSSItem]
    func item(id: UUID) async throws -> RSSItem?
    func updateItemWorkflow(itemID: UUID, status: RSSItemStatus, savedNoteID: UUID?) async throws
}

public protocol RSSFeedDataLoading: Sendable {
    func loadData(from url: URL) async throws -> Data
}

public protocol RSSFeedParsing: Sendable {
    func parse(data: Data, sourceURL: URL) throws -> ParsedRSSDocument
}

public protocol SearchServiceProtocol: Sendable {
    func search(query: String, filters: SearchFilter) async throws -> [Note]
}

public extension SearchServiceProtocol {
    @available(*, deprecated, renamed: "search(query:filters:)", message: "Use search(query:filters:) instead.")
    func search(query: String, filter: SearchFilter) async throws -> [Note] {
        try await search(query: query, filters: filter)
    }
}

public protocol RSSConversionServiceProtocol: Sendable {
    func makeNote(from item: RSSItem, feed: RSSFeed, commentary: String?) -> Note
}

public protocol RSSFetchServiceProtocol: Sendable {
    func refreshAllFeeds() async throws -> RSSRefreshReport
}

public protocol ActionItemExtractionServiceProtocol: Sendable {
    func extract(from transcript: String, sourceNoteID: UUID, referenceDate: Date) -> [ActionItem]
}

public protocol WikiLinkServiceProtocol: Sendable {
    func refreshLinks(for sourceNoteID: UUID) async throws -> [Link]
    func refreshAllLinks() async throws
    func backlinks(to noteID: UUID) async throws -> [Note]
}

public enum SyncConflictPolicy: Sendable {
    case lastWriterWins
    case requiresManualReview
}

public struct SyncConflict: Sendable {
    public var local: Note
    public var remote: Note

    public init(local: Note, remote: Note) {
        self.local = local
        self.remote = remote
    }
}

public enum NoteWriteError: Error, LocalizedError {
    case missingNote, conflict
    public var errorDescription: String? {
        switch self {
        case .missingNote: "This note was deleted. Your unsaved text has been kept in the editor."
        case .conflict: "This note changed in another window or during sync. Copy your unsaved text, then reopen the note before editing again."
        }
    }
}

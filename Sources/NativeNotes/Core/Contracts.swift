import Foundation

public protocol NoteRepository: Sendable {
    func upsert(_ note: Note) async throws
    func delete(noteID: UUID) async throws
    func allNotes() async throws -> [Note]
    func note(id: UUID) async throws -> Note?
}

public protocol LinkRepository: Sendable {
    func replaceLinks(from sourceNoteID: UUID, with links: [Link]) async throws
    func links() async throws -> [Link]
}

public protocol RSSRepository: Sendable {
    func addFeed(_ feed: RSSFeed) async throws
    func feeds() async throws -> [RSSFeed]
    func feed(id: UUID) async throws -> RSSFeed?
    func updateLastFetchedAt(for feedID: UUID, to date: Date?) async throws
    func upsertItems(_ items: [RSSItem]) async throws
    func items(feedID: UUID?) async throws -> [RSSItem]
    func item(id: UUID) async throws -> RSSItem?
}

public protocol SearchServiceProtocol: Sendable {
    func search(query: String, filters: SearchFilter) async throws -> [Note]
}

public extension SearchServiceProtocol {
    @available(*, deprecated, renamed: "search(query:filters:)")
    func search(query: String, filter: SearchFilter) async throws -> [Note] {
        try await search(query: query, filters: filter)
    }
}

public protocol RSSConversionServiceProtocol: Sendable {
    func makeNote(from item: RSSItem, feed: RSSFeed, commentary: String?) -> Note
}

public protocol ActionItemExtractionServiceProtocol: Sendable {
    func extract(from transcript: String, sourceNoteID: UUID, referenceDate: Date) -> [ActionItem]
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

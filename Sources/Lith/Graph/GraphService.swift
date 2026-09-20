import Foundation

public protocol GraphServiceProtocol: Sendable {
    func graph(mode: GraphMode) async throws -> NoteGraph
}

/// Loads fresh repository data on every request. A failed read is surfaced to the
/// caller rather than presenting a partially loaded graph as the complete graph.
public struct GraphService: GraphServiceProtocol {
    private let noteRepository: NoteRepository
    private let linkRepository: LinkRepository
    private let builder = GraphBuilder()

    public init(noteRepository: NoteRepository, linkRepository: LinkRepository) {
        self.noteRepository = noteRepository
        self.linkRepository = linkRepository
    }

    public func graph(mode: GraphMode) async throws -> NoteGraph {
        let notes = try await noteRepository.allNotes()
        let links = try await linkRepository.links()
        try Task.checkCancellation()
        return builder.build(notes: notes, links: links, mode: mode)
    }
}

import Foundation

public struct WikiLinkService: WikiLinkServiceProtocol, Sendable {
    private let noteRepository: NoteRepository
    private let linkRepository: LinkRepository
    private let parser: WikiLinkParser
    private let refreshQueue = WikiLinkRefreshQueue()

    public init(
        noteRepository: NoteRepository,
        linkRepository: LinkRepository,
        parser: WikiLinkParser = WikiLinkParser()
    ) {
        self.noteRepository = noteRepository
        self.linkRepository = linkRepository
        self.parser = parser
    }

    @discardableResult
    public func refreshLinks(for sourceNoteID: UUID) async throws -> [Link] {
        try await refreshQueue.run { try await self.refreshUnqueued(for: sourceNoteID) }
    }

    private func refreshUnqueued(for sourceNoteID: UUID) async throws -> [Link] {
        guard let sourceNote = try await noteRepository.note(id: sourceNoteID) else {
            try await linkRepository.replaceLinks(from: sourceNoteID, with: [])
            return []
        }

        let allNotes = try await noteRepository.allNotes().filter { !$0.isArchived && !$0.isTrashed }
        let retained = try await linkRepository.links(from: sourceNoteID).filter { $0.type != .wikilink }
        let resolvedLinks = (sourceNote.isArchived || sourceNote.isTrashed ? [] : parser.links(for: sourceNote, allNotes: allNotes)) + retained
        try await linkRepository.replaceLinks(from: sourceNoteID, with: resolvedLinks)
        return try await linkRepository.links(from: sourceNoteID)
    }

    public func refreshAllLinks() async throws {
        _ = try await refreshQueue.run {
            let notes = try await self.noteRepository.allNotes()
            let storedLinks = try await self.linkRepository.links()
            let sources = Set(notes.map(\.id)).union(storedLinks.map(\.fromNoteID))
            for id in sources.sorted(by: { $0.uuidString < $1.uuidString }) {
                _ = try await self.refreshUnqueued(for: id)
            }
            return []
        }
    }

    public func backlinks(to noteID: UUID) async throws -> [Note] {
        let backlinks = try await linkRepository.backlinks(to: noteID)
        let sourceNoteIDs = Set(backlinks.map(\.fromNoteID))
        var notes: [Note] = []
        notes.reserveCapacity(sourceNoteIDs.count)

        try await withThrowingTaskGroup(of: Note?.self) { group in
            for sourceNoteID in sourceNoteIDs {
                group.addTask {
                    try await noteRepository.note(id: sourceNoteID)
                }
            }

            for try await note in group {
                if let note {
                    notes.append(note)
                }
            }
        }

        return notes.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}

private actor WikiLinkRefreshQueue {
    private var tail: Task<Void, Never>?
    func run(_ operation: @escaping @Sendable () async throws -> [Link]) async throws -> [Link] {
        let previous = tail
        let task = Task { await previous?.value; return try await operation() }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }
}

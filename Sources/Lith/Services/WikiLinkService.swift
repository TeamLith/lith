import Foundation

public struct WikiLinkService: WikiLinkServiceProtocol, Sendable {
    private let noteRepository: NoteRepository
    private let linkRepository: LinkRepository
    private let parser: WikiLinkParser

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
        guard let sourceNote = try await noteRepository.note(id: sourceNoteID) else {
            try await linkRepository.replaceLinks(from: sourceNoteID, with: [])
            return []
        }

        let allNotes = try await noteRepository.allNotes()
        let resolvedLinks = parser.links(for: sourceNote, allNotes: allNotes)
        try await linkRepository.replaceLinks(from: sourceNoteID, with: resolvedLinks)
        return try await linkRepository.links(from: sourceNoteID)
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

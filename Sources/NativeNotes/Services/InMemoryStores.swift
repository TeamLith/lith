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

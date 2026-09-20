import Foundation

public enum NoteCaptureError: Error, LocalizedError {
    case emptyNote, missingNote
    public var errorDescription: String? {
        switch self {
        case .emptyNote: "Provide a title or some text for your note."
        case .missingNote: "That note is no longer available."
        }
    }
}

/// Shared behavior for Shortcuts/Siri and other capture entry points.
public struct NoteCaptureService: SiriIntentAdapter, Sendable {
    private let repository: NoteRepository
    public init(repository: NoteRepository) { self.repository = repository }

    public func createNote(title: String, content: String) async throws -> Note {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NoteCaptureError.emptyNote
        }
        let fallbackTitle = String(content.split(whereSeparator: \.isNewline).first.map(String.init)?.prefix(80) ?? "Untitled")
        let note = Note(title: title.isEmpty ? fallbackTitle : title, bodyMarkdown: content)
        try await repository.upsert(note)
        return note
    }

    public func appendToNote(noteID: UUID, content: String) async throws -> Note {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw NoteCaptureError.emptyNote }
        guard var note = try await repository.note(id: noteID), !note.isTrashed else { throw NoteCaptureError.missingNote }
        note.bodyMarkdown += (note.bodyMarkdown.isEmpty ? "" : "\n\n") + content
        note.updatedAt = Date()
        try await repository.upsert(note)
        return note
    }
}

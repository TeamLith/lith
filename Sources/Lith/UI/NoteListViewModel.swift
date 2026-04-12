import Foundation
import Observation

/// Observable view model that backs the note list screen.
///
/// Exposes `pinnedNotes` and `recentNotes` derived from the repository.
/// All mutations run on the main actor so SwiftUI can observe changes safely.
@available(iOS 17, macOS 14, *)
@Observable
@MainActor
public final class NoteListViewModel {
    public private(set) var pinnedNotes: [Note] = []
    public private(set) var recentNotes: [Note] = []
    public private(set) var isLoading = false
    public private(set) var loadError: Error?

    private let repository: NoteRepository

    public init(repository: NoteRepository) {
        self.repository = repository
    }

    /// Reload all notes from the repository and split into pinned / recent buckets.
    public func loadNotes() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let all = try await repository.allNotes()
            let visible = all.filter { !$0.isArchived && !$0.isTrashed }
            pinnedNotes = visible
                .filter(\.isPinned)
                .sorted { $0.updatedAt > $1.updatedAt }
            recentNotes = visible
                .filter { !$0.isPinned }
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            loadError = error
        }
    }

    @discardableResult
    public func createNote() async -> Note? {
        let now = Date()
        let note = Note(
            title: "",
            bodyMarkdown: "",
            createdAt: now,
            updatedAt: now
        )

        do {
            try await repository.upsert(note)
            await loadNotes()
            return note
        } catch {
            loadError = error
            return nil
        }
    }

    public func archive(noteID: UUID) async {
        await updateNote(noteID: noteID) { note in
            var updated = note
            updated.isArchived = true
            updated.isTrashed = false
            updated.updatedAt = Date()
            return updated
        }
    }

    public func moveToTrash(noteID: UUID) async {
        await updateNote(noteID: noteID) { note in
            var updated = note
            updated.isArchived = false
            updated.isTrashed = true
            updated.updatedAt = Date()
            return updated
        }
    }

    public func delete(noteID: UUID) async {
        do {
            try await repository.delete(noteID: noteID)
            await loadNotes()
        } catch {
            loadError = error
        }
    }

    private func updateNote(noteID: UUID, mutate: (Note) -> Note) async {
        do {
            guard let note = try await repository.note(id: noteID) else {
                return
            }

            try await repository.upsert(mutate(note))
            await loadNotes()
        } catch {
            loadError = error
        }
    }
}

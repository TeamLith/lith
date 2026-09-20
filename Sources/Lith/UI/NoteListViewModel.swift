import Foundation
import Observation

public enum NoteCollection: String, CaseIterable, Sendable {
    case active = "Notes"
    case archived = "Archive"
    case trashed = "Trash"
}

public enum NoteManagementError: Error, LocalizedError {
    case notTrashed
    public var errorDescription: String? { "Move the note to Trash before deleting it permanently." }
}

/// Observable view model that backs the note list screen.
///
/// Exposes `pinnedNotes` and `recentNotes` derived from the repository.
/// All mutations run on the main actor so SwiftUI can observe changes safely.
@available(iOS 17, macOS 14, *)
@Observable
@MainActor
public final class NoteListViewModel {
    public var collection: NoteCollection = .active
    public private(set) var pinnedNotes: [Note] = []
    public private(set) var recentNotes: [Note] = []
    public private(set) var isLoading = false
    public private(set) var loadError: Error?

    private let repository: NoteRepository
    private let wikiLinkService: WikiLinkServiceProtocol?

    public init(repository: NoteRepository, wikiLinkService: WikiLinkServiceProtocol? = nil) {
        self.repository = repository
        self.wikiLinkService = wikiLinkService
    }

    /// Reload all notes from the repository and split into pinned / recent buckets.
    public func loadNotes() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let all = try await repository.allNotes()
            let visible = all.filter {
                switch collection {
                case .active: !$0.isArchived && !$0.isTrashed
                case .archived: $0.isArchived && !$0.isTrashed
                case .trashed: $0.isTrashed
                }
            }
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
            try await wikiLinkService?.refreshAllLinks()
            collection = .active
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

    public func restore(noteID: UUID) async {
        await updateNote(noteID: noteID) { note in
            var restored = note
            restored.isArchived = false
            restored.isTrashed = false
            restored.updatedAt = Date()
            return restored
        }
    }

    @discardableResult
    public func importMarkdown(data: Data, filename: String, wikiLinkService: WikiLinkServiceProtocol) async -> Note? {
        do {
            let note = try await MarkdownNoteService().importNote(data: data, filename: filename, repository: repository, wikiLinkService: wikiLinkService)
            collection = .active
            await loadNotes()
            return note
        } catch { loadError = error; return nil }
    }

    public func delete(noteID: UUID) async {
        do {
            guard let note = try await repository.note(id: noteID) else { return }
            guard note.isTrashed else { throw NoteManagementError.notTrashed }
            try await repository.delete(noteID: noteID)
            try await wikiLinkService?.refreshAllLinks()
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

            try await repository.updateExisting(mutate(note), expected: note)
            try await wikiLinkService?.refreshAllLinks()
            await loadNotes()
        } catch {
            loadError = error
        }
    }
}

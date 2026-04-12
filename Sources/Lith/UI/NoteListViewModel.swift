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
}

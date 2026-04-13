import Foundation
import Observation

@available(iOS 17, macOS 14, *)
@Observable
@MainActor
public final class NoteDetailViewModel {
    public let noteID: UUID

    public var title = ""
    public var bodyMarkdown = ""
    public var isPinned = false
    public private(set) var backlinks: [Note] = []

    public private(set) var isArchived = false
    public private(set) var isTrashed = false
    public private(set) var updatedAt: Date?
    public private(set) var isLoading = false
    public private(set) var loadError: Error?
    public private(set) var saveError: Error?

    private let repository: NoteRepository
    private let wikiLinkService: WikiLinkServiceProtocol
    private let autosaveDelayNanoseconds: UInt64

    private var existingNote: Note?
    private var autosaveTask: Task<Void, Never>?

    public init(
        noteID: UUID,
        repository: NoteRepository,
        wikiLinkService: WikiLinkServiceProtocol,
        autosaveDelayNanoseconds: UInt64 = 500_000_000
    ) {
        self.noteID = noteID
        self.repository = repository
        self.wikiLinkService = wikiLinkService
        self.autosaveDelayNanoseconds = autosaveDelayNanoseconds
    }

    public func loadNote() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            guard let note = try await repository.note(id: noteID) else {
                throw NoteDetailViewModelError.noteNotFound(noteID)
            }

            apply(note)
            existingNote = note
            backlinks = try await wikiLinkService.backlinks(to: noteID)
            saveError = nil
        } catch {
            loadError = error
        }
    }

    public func scheduleAutosave() {
        guard existingNote != nil, hasUnsavedChanges else {
            return
        }

        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.autosaveDelayNanoseconds ?? 0)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            await self?.saveNow()
        }
    }

    @discardableResult
    public func saveNow() async -> Note? {
        autosaveTask?.cancel()
        guard hasUnsavedChanges else {
            saveError = nil
            return existingNote
        }
        guard let note = makeCurrentNote() else {
            return nil
        }

        do {
            try await repository.upsert(note)
            _ = try await wikiLinkService.refreshLinks(for: note.id)
            backlinks = try await wikiLinkService.backlinks(to: note.id)
            existingNote = note
            updatedAt = note.updatedAt
            saveError = nil
            return note
        } catch {
            saveError = error
            return nil
        }
    }

    @discardableResult
    public func archive() async -> Note? {
        isArchived = true
        isTrashed = false
        return await saveNow()
    }

    @discardableResult
    public func moveToTrash() async -> Note? {
        isArchived = false
        isTrashed = true
        return await saveNow()
    }

    private func apply(_ note: Note) {
        title = note.title
        bodyMarkdown = note.bodyMarkdown
        isPinned = note.isPinned
        isArchived = note.isArchived
        isTrashed = note.isTrashed
        updatedAt = note.updatedAt
    }

    private func makeCurrentNote() -> Note? {
        guard let existingNote else {
            return nil
        }

        let now = Date()
        return Note(
            id: existingNote.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            bodyMarkdown: bodyMarkdown,
            tags: existingNote.tags,
            createdAt: existingNote.createdAt,
            updatedAt: now,
            accessedAt: existingNote.accessedAt,
            source: existingNote.source,
            isPinned: isPinned,
            isArchived: isArchived,
            isTrashed: isTrashed,
            metadata: existingNote.metadata
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let existingNote else {
            return false
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines) != existingNote.title
            || bodyMarkdown != existingNote.bodyMarkdown
            || isPinned != existingNote.isPinned
            || isArchived != existingNote.isArchived
            || isTrashed != existingNote.isTrashed
    }
}

enum NoteDetailViewModelError: LocalizedError {
    case noteNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case let .noteNotFound(noteID):
            return "The note with id \(noteID.uuidString) could not be loaded."
        }
    }
}

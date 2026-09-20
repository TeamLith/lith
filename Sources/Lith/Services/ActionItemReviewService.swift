import Foundation

public protocol ActionItemRepository: Sendable {
    func upsert(_ item: ActionItem) async throws
    func items(noteID: UUID?) async throws -> [ActionItem]
    func item(id: UUID) async throws -> ActionItem?
    func delete(itemID: UUID) async throws
}

public enum ActionItemReviewError: Error, LocalizedError {
    case emptyTask, missingNote
    public var errorDescription: String? {
        switch self {
        case .emptyTask: "Enter an action before accepting it."
        case .missingNote: "The source note is no longer available."
        }
    }
}

public actor ActionItemReviewService {
    private let repository: ActionItemRepository
    private let notes: NoteRepository
    private let extractor: ActionItemExtractionService
    private var pending: [UUID: Task<ActionItem, Error>] = [:]

    public init(repository: ActionItemRepository, notes: NoteRepository, extractor: ActionItemExtractionService = .init()) {
        self.repository = repository
        self.notes = notes
        self.extractor = extractor
    }

    public func drafts(from transcript: String, noteID: UUID, referenceDate: Date = Date()) async throws -> [ActionItemDraft] {
        let accepted = Set(try await repository.items(noteID: noteID).map(\.id))
        return extractor.drafts(from: transcript, sourceNoteID: noteID, referenceDate: referenceDate).filter { !accepted.contains($0.id) }
    }

    /// Acceptance is explicit. Existing accepted items retain edits and completion.
    @discardableResult
    public func accept(_ draft: ActionItemDraft, at date: Date = Date()) async throws -> ActionItem {
        if let pending = pending[draft.id] { return try await pending.value }
        let task = Task { [repository, notes] in
            if let existing = try await repository.item(id: draft.id) { return existing }
            guard let note = try await notes.note(id: draft.sourceNoteID), !note.isTrashed else { throw ActionItemReviewError.missingNote }
            let task = draft.task.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !task.isEmpty else { throw ActionItemReviewError.emptyTask }
            let item = ActionItem(id: draft.id, sourceNoteID: draft.sourceNoteID, task: task,
                                  assignee: draft.assignee, dueDate: draft.dueDate, createdAt: date, updatedAt: date)
            try await repository.upsert(item)
            return item
        }
        pending[draft.id] = task
        defer { pending[draft.id] = nil }
        return try await task.value
    }
}

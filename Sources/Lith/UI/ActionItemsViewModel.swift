import Foundation
import Observation

@Observable
@MainActor
public final class ActionItemsViewModel {
    public let noteID: UUID
    public private(set) var items: [ActionItem] = []
    public private(set) var drafts: [ActionItemDraft] = []
    public private(set) var isBusy = false
    public private(set) var hasExtracted = false
    public private(set) var errorMessage: String?
    private let repository: ActionItemRepository
    private let review: ActionItemReviewService
    private let transcriptProvider: (@Sendable (UUID) async throws -> String)?

    public init(noteID: UUID, repository: ActionItemRepository, notes: NoteRepository,
                reviewService: ActionItemReviewService? = nil,
                transcriptProvider: (@Sendable (UUID) async throws -> String)? = nil) {
        self.noteID = noteID
        self.repository = repository
        self.review = reviewService ?? ActionItemReviewService(repository: repository, notes: notes)
        self.transcriptProvider = transcriptProvider
    }

    public func load() async {
        await perform { self.items = try await self.repository.items(noteID: self.noteID) }
    }

    public func propose(from body: String, referenceDate: Date = Date()) async {
        await perform {
            let transcript = try await self.transcriptProvider?(self.noteID) ?? ""
            self.drafts = try await self.review.drafts(from: [body, transcript].joined(separator: "\n"), noteID: self.noteID, referenceDate: referenceDate)
            self.hasExtracted = true
        }
    }

    public func dismissDraft(_ id: UUID) { drafts.removeAll { $0.id == id } }

    @discardableResult
    public func accept(_ draft: ActionItemDraft) async -> Bool {
        await perform {
            guard draft.sourceNoteID == self.noteID else { throw ActionItemReviewError.missingNote }
            _ = try await self.review.accept(draft)
            self.items = try await self.repository.items(noteID: self.noteID)
            self.drafts.removeAll { $0.id == draft.id }
        }
    }

    @discardableResult
    public func update(id: UUID, task: String, assignee: String?, dueDate: Date?) async -> Bool {
        await perform {
            var item = try await self.existing(id)
            item.task = task.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.task.isEmpty else { throw ActionItemReviewError.emptyTask }
            let name = assignee?.trimmingCharacters(in: .whitespacesAndNewlines)
            item.assignee = name?.isEmpty == false ? name : nil
            item.dueDate = dueDate
            item.updatedAt = Date()
            try await self.repository.upsert(item)
            self.items = try await self.repository.items(noteID: self.noteID)
        }
    }

    public func setCompleted(id: UUID, completed: Bool) async {
        await perform {
            var item = try await self.existing(id)
            item.status = completed ? .done : .open
            item.updatedAt = Date()
            try await self.repository.upsert(item)
            self.items = try await self.repository.items(noteID: self.noteID)
        }
    }

    public func delete(id: UUID) async {
        await perform {
            _ = try await self.existing(id)
            try await self.repository.delete(itemID: id)
            self.items = try await self.repository.items(noteID: self.noteID)
        }
    }

    /// Only persisted, accepted records enter the user-initiated sharing payload.
    public var exportText: String {
        items.filter { $0.status != .dropped }.map { item in
            var text = "- [\(item.status == .done ? "x" : " ")] \(item.task)"
            if let assignee = item.assignee, !assignee.isEmpty { text += " — \(assignee)" }
            if let date = item.dueDate { text += " (due \(date.formatted(date: .abbreviated, time: .omitted)))" }
            return text
        }.joined(separator: "\n")
    }

    private func existing(_ id: UUID) async throws -> ActionItem {
        guard let item = try await repository.item(id: id), item.sourceNoteID == noteID else { throw ActionItemReviewError.missingNote }
        return item
    }

    @discardableResult
    private func perform(_ operation: () async throws -> Void) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do { try await operation(); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
}

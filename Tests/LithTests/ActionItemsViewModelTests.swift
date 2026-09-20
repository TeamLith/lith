import Foundation
import Testing
@testable import Lith

@MainActor
@Suite("Action checklist lifecycle")
struct ActionItemsViewModelTests {
    #if canImport(CoreData)
    @Test("Suggestions require acceptance and accepted actions support edit, complete, reopen and delete")
    func lifecycle() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let note = Note(title: "Meeting", bodyMarkdown: "TODO: Send report")
        try await dependencies.noteRepository.upsert(note)
        let vm = ActionItemsViewModel(noteID: note.id, repository: dependencies.actionItemRepository, notes: dependencies.noteRepository,
                                     transcriptProvider: { _ in "Alice will check the figures tomorrow" })
        await vm.load()
        await vm.propose(from: note.bodyMarkdown)
        #expect(vm.drafts.count == 2)
        #expect(vm.items.isEmpty)
        #expect(vm.exportText.isEmpty)
        var draft = try #require(vm.drafts.first)
        draft.task = "Send reviewed report"
        draft.assignee = "Bob"
        #expect(await vm.accept(draft))
        #expect(vm.items.count == 1)
        #expect(vm.drafts.count == 1)
        #expect(vm.exportText.contains("Send reviewed report"))
        #expect(!vm.exportText.contains("Alice"))
        await vm.setCompleted(id: draft.id, completed: true)
        #expect(vm.items.first?.status == .done)
        #expect(vm.exportText.contains("[x]"))
        await vm.setCompleted(id: draft.id, completed: false)
        #expect(vm.items.first?.status == .open)
        let due = Date(timeIntervalSince1970: 2_000_000)
        #expect(await vm.update(id: draft.id, task: "Updated task", assignee: "  Jo ", dueDate: due))
        #expect(vm.items.first?.task == "Updated task")
        #expect(vm.items.first?.assignee == "Jo")
        #expect(vm.items.first?.dueDate == due)
        #expect(vm.items.first?.updatedAt != nil)
        await vm.propose(from: note.bodyMarkdown)
        #expect(!vm.drafts.contains { $0.id == draft.id })
        let reopened = ActionItemsViewModel(noteID: note.id, repository: dependencies.actionItemRepository, notes: dependencies.noteRepository)
        await reopened.load()
        #expect(reopened.items == vm.items)
        await vm.delete(id: draft.id)
        #expect(vm.items.isEmpty)
        #expect(vm.exportText.isEmpty)
    }

    @Test("Invalid edits and actions from another note are rejected without persistence changes")
    func validation() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let note = Note(title: "Note", bodyMarkdown: "")
        try await dependencies.noteRepository.upsert(note)
        let item = ActionItem(sourceNoteID: note.id, task: "Keep")
        try await dependencies.actionItemRepository.upsert(item)
        let vm = ActionItemsViewModel(noteID: note.id, repository: dependencies.actionItemRepository, notes: dependencies.noteRepository)
        await vm.load()
        #expect(!(await vm.update(id: item.id, task: "  ", assignee: nil, dueDate: nil)))
        #expect(vm.errorMessage != nil)
        #expect(vm.items == [item])
        let other = ActionItem(sourceNoteID: UUID(), task: "Other")
        try await dependencies.actionItemRepository.upsert(other)
        await vm.delete(id: other.id)
        #expect(try await dependencies.actionItemRepository.item(id: other.id) == other)
        let draft = ActionItemDraft(id: UUID(), sourceNoteID: other.sourceNoteID, sourceText: "", task: "Other draft")
        #expect(!(await vm.accept(draft)))
    }
    #endif

    @Test("Failed persistence leaves the checklist intact and retry can recover")
    func saveFailure() async throws {
        let note = Note(title: "Note", bodyMarkdown: "")
        let item = ActionItem(sourceNoteID: note.id, task: "Keep")
        let repository = FailingActionRepository(item: item)
        let vm = ActionItemsViewModel(noteID: note.id, repository: repository, notes: InMemoryNoteRepository(seed: [note]))
        await vm.load()
        await vm.setCompleted(id: item.id, completed: true)
        #expect(vm.errorMessage != nil)
        #expect(vm.items.first?.status == .open)
        #expect(!vm.isBusy)
        await repository.allowSave()
        await vm.setCompleted(id: item.id, completed: true)
        #expect(vm.errorMessage == nil)
        #expect(vm.items.first?.status == .done)
    }

    @Test("Transcript failures surface an error without sharing or accepting drafts")
    func transcriptFailure() async {
        let note = Note(title: "Note", bodyMarkdown: "")
        let repository = FailingActionRepository(item: ActionItem(sourceNoteID: note.id, task: "Accepted"))
        let vm = ActionItemsViewModel(noteID: note.id, repository: repository, notes: InMemoryNoteRepository(seed: [note]),
                                     transcriptProvider: { _ in throw ActionChecklistError.failed })
        await vm.propose(from: "TODO: new action")
        #expect(vm.errorMessage != nil)
        #expect(vm.drafts.isEmpty)
        #expect(vm.exportText.isEmpty)
    }
}

private enum ActionChecklistError: Error { case failed }
private actor FailingActionRepository: ActionItemRepository {
    private var stored: ActionItem
    private var fails = true
    init(item: ActionItem) { stored = item }
    func allowSave() { fails = false }
    func upsert(_ item: ActionItem) async throws {
        if fails { throw ActionChecklistError.failed }
        stored = item
    }
    func items(noteID: UUID?) async throws -> [ActionItem] { [stored] }
    func item(id: UUID) async throws -> ActionItem? { id == stored.id ? stored : nil }
    func delete(itemID: UUID) async throws { throw ActionChecklistError.failed }
}

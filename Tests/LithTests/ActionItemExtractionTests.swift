import Foundation
import Testing
@testable import Lith

@Suite("Action extraction and acceptance")
struct ActionItemExtractionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private var referenceDate: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 10))! }

    @Test("Canned transcript produces conservative drafts, names and dates")
    func cannedTranscript() {
        let transcript = """
        We discussed a proposal by Friday. Nobody committed to it.
        I will send the notes tomorrow. Alice will review the design next Friday.
        TODO: Update the website in two weeks.
        Action item: Prepare agenda assigned to Bob by 2026-10-01.
        We will not publish the draft. I won't call.
        Follow up with the designer by EOD.
        """
        let drafts = ActionItemExtractionService(calendar: calendar).drafts(from: transcript, sourceNoteID: UUID(), referenceDate: referenceDate)
        #expect(drafts.count == 5)
        #expect(drafts[0].assignee == "I")
        #expect(drafts[1].assignee == "Alice")
        #expect(drafts[3].assignee == "Bob")
        #expect(drafts[0].dueDate == calendar.date(from: DateComponents(year: 2026, month: 9, day: 19)))
        #expect(drafts[1].dueDate == calendar.date(from: DateComponents(year: 2026, month: 9, day: 25)))
        #expect(drafts[2].dueDate == calendar.date(from: DateComponents(year: 2026, month: 10, day: 2)))
        #expect(drafts[3].dueDate == calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        #expect(drafts[4].dueDate == calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 17)))
    }

    @Test("Repeated drafts have stable IDs, ambiguous prose stays unparsed and invalid dates stay empty")
    func identityAndAmbiguity() {
        let extractor = ActionItemExtractionService(calendar: calendar)
        let id = UUID()
        let transcript = "TODO: Review the document\nTODO: review   the document\nThe house is by the lake\nPerhaps Alice will review it\nTODO: Ship by 2026-02-30\nTODO: Visit https://example.com/docs"
        let first = extractor.drafts(from: transcript, sourceNoteID: id, referenceDate: referenceDate)
        let next = extractor.drafts(from: transcript, sourceNoteID: id, referenceDate: referenceDate.addingTimeInterval(86_400))
        #expect(first.count == 3)
        #expect(first.map(\.id) == next.map(\.id))
        #expect(first[1].dueDate == nil)
        #expect(first[2].task.contains("example.com/docs"))
        #expect(extractor.drafts(from: transcript, sourceNoteID: UUID()).first?.id != first.first?.id)
    }

    @Test("Legacy action JSON decodes without new optional dates")
    func legacyPayload() throws {
        let id = UUID(), note = UUID()
        let data = Data("{\"id\":\"\(id)\",\"sourceNoteID\":\"\(note)\",\"task\":\"Old\",\"status\":\"done\"}".utf8)
        let decoded = try JSONDecoder().decode(ActionItem.self, from: data)
        #expect(decoded.status == .done)
        #expect(decoded.createdAt == nil)
        #expect(decoded.updatedAt == nil)
    }

    #if canImport(CoreData)
    @Test("Only acceptance persists; re-extraction preserves edited completed actions")
    func explicitAcceptance() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let note = Note(title: "Meeting", bodyMarkdown: "")
        try await dependencies.noteRepository.upsert(note)
        let review = ActionItemReviewService(repository: dependencies.actionItemRepository, notes: dependencies.noteRepository)
        let drafts = try await review.drafts(from: "TODO: Send report tomorrow", noteID: note.id, referenceDate: referenceDate)
        #expect(try await dependencies.actionItemRepository.items(noteID: note.id).isEmpty)
        var accepted = try await review.accept(try #require(drafts.first), at: referenceDate)
        #expect(accepted.createdAt == referenceDate)
        accepted.task = "Send the revised report"
        accepted.status = .done
        try await dependencies.actionItemRepository.upsert(accepted)
        let repeatDrafts = try await review.drafts(from: "TODO: Send report tomorrow", noteID: note.id, referenceDate: referenceDate)
        #expect(repeatDrafts.isEmpty)
        let repeated = try await review.accept(drafts[0])
        #expect(repeated.task == "Send the revised report")
        #expect(repeated.status == .done)
        let reopened = CoreDataActionItemRepository(container: dependencies.persistentContainer)
        #expect(try await reopened.item(id: accepted.id) == accepted)
        #expect(try await reopened.items(noteID: UUID()).isEmpty)
        try await reopened.delete(itemID: accepted.id)
        #expect(try await reopened.items(noteID: nil).isEmpty)
    }

    @Test("Concurrent acceptance of the same draft persists one item")
    func concurrentAcceptance() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let note = Note(title: "Meeting", bodyMarkdown: "")
        try await dependencies.noteRepository.upsert(note)
        let service = ActionItemReviewService(repository: dependencies.actionItemRepository, notes: dependencies.noteRepository)
        let draft = ActionItemDraft(id: UUID(), sourceNoteID: note.id, sourceText: "TODO: Send", task: "Send")
        async let first = service.accept(draft)
        async let second = service.accept(draft)
        let values = try await [first, second]
        #expect(values[0] == values[1])
        #expect(try await dependencies.actionItemRepository.items(noteID: note.id).count == 1)
    }

    @Test("Acceptance rejects empty tasks and unavailable source notes")
    func validation() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let note = Note(title: "Meeting", bodyMarkdown: "")
        try await dependencies.noteRepository.upsert(note)
        let service = ActionItemReviewService(repository: dependencies.actionItemRepository, notes: dependencies.noteRepository)
        let empty = ActionItemDraft(id: UUID(), sourceNoteID: note.id, sourceText: "", task: "  ")
        await #expect(throws: ActionItemReviewError.self) { try await service.accept(empty) }
        let missing = ActionItemDraft(id: UUID(), sourceNoteID: UUID(), sourceText: "", task: "Task")
        await #expect(throws: ActionItemReviewError.self) { try await service.accept(missing) }
        #expect(try await dependencies.actionItemRepository.items(noteID: nil).isEmpty)
    }
    #endif
}

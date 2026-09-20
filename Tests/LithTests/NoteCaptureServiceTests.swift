import Foundation
import Testing
@testable import Lith

@Test func siriCaptureMapsInputAndPersistsNote() async throws {
    let repository = InMemoryNoteRepository()
    let service = NoteCaptureService(repository: repository)
    let note = try await service.createNote(title: "  Shopping  ", content: "- Milk\n- Bread")
    #expect(note.title == "Shopping")
    #expect(note.bodyMarkdown == "- Milk\n- Bread")
    #expect(note.source == .manual)
    #expect(try await repository.note(id: note.id) == note)
    let appended = try await service.appendToNote(noteID: note.id, content: "- Coffee")
    #expect(appended.id == note.id)
    #expect(appended.bodyMarkdown == "- Milk\n- Bread\n\n- Coffee")
}

@Test func siriCaptureRejectsBlankInputAndPropagatesStorageErrors() async throws {
    let repo = InMemoryNoteRepository()
    let service = NoteCaptureService(repository: repo)
    await #expect(throws: NoteCaptureError.self) { try await service.createNote(title: " \n", content: "  ") }
    #expect(try await repo.allNotes().isEmpty)
    let derived = try await service.createNote(title: "", content: "Meeting\nAgenda")
    #expect(derived.title == "Meeting")
    await #expect(throws: NoteCaptureError.self) { try await service.appendToNote(noteID: UUID(), content: "Missing") }
    await #expect(throws: CaptureTestError.self) {
        try await NoteCaptureService(repository: FailingCaptureRepository()).createNote(title: "Keep", content: "safe")
    }
}

private enum CaptureTestError: Error { case storage }
private struct FailingCaptureRepository: NoteRepository {
    func updateExisting(_ note: Note, expected: Note) async throws { try await upsert(note) }
    func upsert(_ note: Note) async throws { throw CaptureTestError.storage }
    func delete(noteID: UUID) async throws {}
    func allNotes() async throws -> [Note] { [] }
    func note(id: UUID) async throws -> Note? { nil }
}

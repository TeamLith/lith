import Foundation
import Testing
@testable import Lith

@MainActor
@Suite("NoteDetailViewModel")
struct NoteDetailViewModelTests {
    @Test("loadNote hydrates the editable draft from the repository")
    func loadNoteHydratesDraft() async {
        let note = Note(
            title: "Hydrate",
            bodyMarkdown: "Seed body",
            isPinned: true
        )
        let repo = InMemoryNoteRepository(seed: [note])
        let vm = NoteDetailViewModel(noteID: note.id, repository: repo)

        await vm.loadNote()

        #expect(vm.title == note.title)
        #expect(vm.bodyMarkdown == note.bodyMarkdown)
        #expect(vm.isPinned == note.isPinned)
        #expect(vm.loadError == nil)
    }

    @Test("scheduleAutosave persists title and body edits")
    func scheduleAutosavePersistsEdits() async throws {
        let note = Note(title: "Original", bodyMarkdown: "Before")
        let repo = InMemoryNoteRepository(seed: [note])
        let vm = NoteDetailViewModel(
            noteID: note.id,
            repository: repo,
            autosaveDelayNanoseconds: 20_000_000
        )

        await vm.loadNote()
        vm.title = "Updated"
        vm.bodyMarkdown = "After"
        vm.scheduleAutosave()

        try await Task.sleep(nanoseconds: 120_000_000)

        let stored = try await repo.note(id: note.id)
        #expect(stored?.title == "Updated")
        #expect(stored?.bodyMarkdown == "After")
    }

    @Test("archive persists archived state")
    func archivePersistsArchivedState() async throws {
        let note = Note(title: "Archive", bodyMarkdown: "Body")
        let repo = InMemoryNoteRepository(seed: [note])
        let vm = NoteDetailViewModel(noteID: note.id, repository: repo)

        await vm.loadNote()
        _ = await vm.archive()

        let stored = try await repo.note(id: note.id)
        #expect(stored?.isArchived == true)
        #expect(stored?.isTrashed == false)
    }
}

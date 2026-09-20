import Foundation
import Testing
@testable import Lith
#if canImport(CoreData)
import CoreData
#endif

@MainActor
@Suite("Note lifecycle safety")
struct NoteLifecycleSafetyTests {
    @Test("Immediate flush persists edits before a long autosave delay")
    func flush() async throws {
        let note = Note(title: "Original", bodyMarkdown: "")
        let notes = InMemoryNoteRepository(seed: [note])
        let vm = NoteDetailViewModel(noteID: note.id, repository: notes,
                                    wikiLinkService: WikiLinkService(noteRepository: notes, linkRepository: InMemoryLinkRepository()),
                                    autosaveDelayNanoseconds: 60_000_000_000)
        await vm.loadNote()
        vm.bodyMarkdown = "Typed immediately before closing"
        vm.scheduleAutosave()
        #expect(await vm.saveNow() != nil)
        #expect(try await notes.note(id: note.id)?.bodyMarkdown == "Typed immediately before closing")
    }

    @Test("Stale editor cannot resurrect deleted notes or undo trash from another window")
    func staleEditor() async throws {
        for delete in [false, true] {
            let note = Note(title: "Original", bodyMarkdown: "")
            let notes = InMemoryNoteRepository(seed: [note])
            let vm = NoteDetailViewModel(noteID: note.id, repository: notes,
                                        wikiLinkService: WikiLinkService(noteRepository: notes, linkRepository: InMemoryLinkRepository()))
            await vm.loadNote()
            vm.bodyMarkdown = "Unsaved local text"
            if delete { try await notes.delete(noteID: note.id) }
            else {
                var trashed = note
                trashed.isTrashed = true
                try await notes.updateExisting(trashed, expected: note)
            }
            #expect(await vm.saveNow() == nil)
            #expect(vm.saveError != nil)
            #expect(vm.bodyMarkdown == "Unsaved local text")
            if delete { #expect(try await notes.note(id: note.id) == nil) }
            else { #expect(try await notes.note(id: note.id)?.isTrashed == true) }
        }
    }

    @Test("Creating and renaming targets reindexes earlier unresolved incoming links")
    func targetChanges() async throws {
        let source = Note(title: "Source", bodyMarkdown: "[[Later]]")
        let notes = InMemoryNoteRepository(seed: [source])
        let links = InMemoryLinkRepository()
        let wiki = WikiLinkService(noteRepository: notes, linkRepository: links)
        try await wiki.refreshAllLinks()
        #expect(try await links.links().isEmpty)
        let target = try await NoteCaptureService(repository: notes, wikiLinkService: wiki).createNote(title: "Later", content: "")
        #expect(try await links.backlinks(to: target.id).map(\.fromNoteID) == [source.id])
        let vm = NoteDetailViewModel(noteID: target.id, repository: notes, wikiLinkService: wiki)
        await vm.loadNote()
        vm.title = "Renamed"
        #expect(await vm.saveNow() != nil)
        #expect(try await links.links().isEmpty)
        vm.title = "Later"
        _ = await vm.saveNow()
        #expect(try await links.links().count == 1)
        let list = NoteListViewModel(repository: notes, wikiLinkService: wiki)
        await list.moveToTrash(noteID: target.id)
        #expect(try await links.links().isEmpty)
        await list.restore(noteID: target.id)
        #expect(try await links.links().count == 1)
    }

    #if canImport(CoreData)
    @Test("Core Data CAS detects another repository's deletion and concurrent edit")
    func persistentCAS() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let second = CoreDataNoteRepository(container: dependencies.persistentContainer)
        let original = Note(title: "Original", bodyMarkdown: "")
        try await dependencies.noteRepository.upsert(original)
        _ = try await second.note(id: original.id)
        var revised = original; revised.title = "New title"
        try await dependencies.noteRepository.updateExisting(revised, expected: original)
        await #expect(throws: NoteWriteError.self) { try await second.updateExisting(original, expected: original) }
        try await dependencies.noteRepository.delete(noteID: original.id)
        await #expect(throws: NoteWriteError.self) { try await second.updateExisting(revised, expected: revised) }
        #expect(try await second.note(id: original.id) == nil)
    }

    @Test("Permanent deletion removes related records and owned files while preserving other notes")
    func cascadeDelete() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = AudioFileStore(root: root)
        let notes = CoreDataNoteRepository(container: dependencies.persistentContainer, files: files)
        let audio = CoreDataAudioRecordingRepository(container: dependencies.persistentContainer, files: files)
        let note = Note(title: "Delete", bodyMarkdown: "", isTrashed: false)
        let other = Note(title: "Keep", bodyMarkdown: "")
        try await notes.upsert(note); try await notes.upsert(other)
        let action = ActionItem(sourceNoteID: note.id, task: "Associated action")
        try await dependencies.actionItemRepository.upsert(action)
        let id = UUID()
        let url = try files.prepare(noteID: note.id, recordingID: id)
        try Data("audio".utf8).write(to: url)
        let recording = AudioRecording(id: id, noteID: note.id, fileURL: url)
        try await audio.upsert(recording)
        try await dependencies.linkRepository.replaceLinks(from: other.id, with: [Link(fromNoteID: other.id, toNoteID: note.id, type: .wikilink)])
        try await notes.delete(noteID: note.id)
        #expect(try await notes.note(id: note.id) == nil)
        #expect(try await notes.note(id: other.id) == other)
        #expect(try await CoreDataActionItemRepository(container: dependencies.persistentContainer).items(noteID: note.id).isEmpty)
        #expect(try await CoreDataAudioRecordingRepository(container: dependencies.persistentContainer, files: files).recordings(noteID: note.id).isEmpty)
        #expect(try await CoreDataLinkRepository(container: dependencies.persistentContainer).links().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        await #expect(throws: ActionItemReviewError.self) { try await dependencies.actionItemRepository.upsert(action) }
    }

    @Test("Action update cannot recreate an individually deleted action")
    func staleAction() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let note = Note(title: "Note", bodyMarkdown: "")
        try await dependencies.noteRepository.upsert(note)
        let item = ActionItem(sourceNoteID: note.id, task: "Task")
        try await dependencies.actionItemRepository.upsert(item)
        try await dependencies.actionItemRepository.delete(itemID: item.id)
        await #expect(throws: ActionItemReviewError.self) { try await dependencies.actionItemRepository.updateExisting(item, expected: item) }
        #expect(try await dependencies.actionItemRepository.items(noteID: note.id).isEmpty)
    }
    #endif
}

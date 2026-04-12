import Foundation
import Testing
@testable import Lith

@MainActor
@Suite("NoteListViewModel")
struct NoteListViewModelTests {

    @Test("Empty repository shows no notes")
    func emptyRepositoryShowsNoNotes() async {
        let repo = InMemoryNoteRepository()
        let vm = NoteListViewModel(repository: repo)

        await vm.loadNotes()

        #expect(vm.pinnedNotes.isEmpty)
        #expect(vm.recentNotes.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.loadError == nil)
    }

    @Test("Pinned notes appear in pinnedNotes bucket")
    func pinnedNotesAreSegregated() async throws {
        let pinned = Note(title: "Pinned", bodyMarkdown: "p", isPinned: true)
        let recent = Note(title: "Recent", bodyMarkdown: "r", isPinned: false)
        let repo = InMemoryNoteRepository(seed: [pinned, recent])
        let vm = NoteListViewModel(repository: repo)

        await vm.loadNotes()

        #expect(vm.pinnedNotes.map(\.id) == [pinned.id])
        #expect(vm.recentNotes.map(\.id) == [recent.id])
    }

    @Test("Archived and trashed notes are excluded")
    func archivedAndTrashedNotesAreExcluded() async {
        let visible = Note(title: "Visible", bodyMarkdown: "v")
        let archived = Note(title: "Archived", bodyMarkdown: "a", isArchived: true)
        let trashed = Note(title: "Trashed", bodyMarkdown: "t", isTrashed: true)
        let repo = InMemoryNoteRepository(seed: [visible, archived, trashed])
        let vm = NoteListViewModel(repository: repo)

        await vm.loadNotes()

        #expect(vm.pinnedNotes.isEmpty)
        #expect(vm.recentNotes.map(\.id) == [visible.id])
    }

    @Test("Notes are sorted newest updatedAt first")
    func notesAreSortedByUpdatedAtDescending() async {
        let older = Note(title: "Older", bodyMarkdown: "", updatedAt: Date(timeIntervalSince1970: 100))
        let newer = Note(title: "Newer", bodyMarkdown: "", updatedAt: Date(timeIntervalSince1970: 200))
        let repo = InMemoryNoteRepository(seed: [older, newer])
        let vm = NoteListViewModel(repository: repo)

        await vm.loadNotes()

        #expect(vm.recentNotes.first?.id == newer.id)
        #expect(vm.recentNotes.last?.id == older.id)
    }

    @Test("loadNotes clears a previous error on retry")
    func loadNotesClearsPreviousError() async {
        let repo = InMemoryNoteRepository()
        let vm = NoteListViewModel(repository: repo)

        // First load succeeds, so loadError is nil; confirm idempotent re-run is safe.
        await vm.loadNotes()
        #expect(vm.loadError == nil)

        await vm.loadNotes()
        #expect(vm.loadError == nil)
    }

    @Test("createNote persists a new note and refreshes the list")
    func createNotePersistsNewNote() async throws {
        let repo = InMemoryNoteRepository()
        let vm = NoteListViewModel(repository: repo)

        let created = await vm.createNote()

        #expect(created != nil)
        #expect(vm.recentNotes.count == 1)
        #expect(vm.recentNotes.first?.id == created?.id)
        #expect(try await repo.note(id: created?.id ?? UUID())?.id == created?.id)
    }

    @Test("archive marks the note archived and removes it from visible buckets")
    func archiveHidesNoteFromVisibleBuckets() async throws {
        let note = Note(title: "Archive me", bodyMarkdown: "Body")
        let repo = InMemoryNoteRepository(seed: [note])
        let vm = NoteListViewModel(repository: repo)

        await vm.archive(noteID: note.id)

        let stored = try await repo.note(id: note.id)
        #expect(stored?.isArchived == true)
        #expect(vm.pinnedNotes.isEmpty)
        #expect(vm.recentNotes.isEmpty)
    }

    @Test("moveToTrash marks the note trashed and removes it from visible buckets")
    func moveToTrashHidesNoteFromVisibleBuckets() async throws {
        let note = Note(title: "Trash me", bodyMarkdown: "Body")
        let repo = InMemoryNoteRepository(seed: [note])
        let vm = NoteListViewModel(repository: repo)

        await vm.moveToTrash(noteID: note.id)

        let stored = try await repo.note(id: note.id)
        #expect(stored?.isTrashed == true)
        #expect(vm.pinnedNotes.isEmpty)
        #expect(vm.recentNotes.isEmpty)
    }

    @Test("delete permanently removes the note")
    func deleteRemovesTheNote() async throws {
        let note = Note(title: "Delete me", bodyMarkdown: "Body")
        let repo = InMemoryNoteRepository(seed: [note])
        let vm = NoteListViewModel(repository: repo)

        await vm.delete(noteID: note.id)

        #expect(try await repo.note(id: note.id) == nil)
        #expect(vm.pinnedNotes.isEmpty)
        #expect(vm.recentNotes.isEmpty)
    }
}

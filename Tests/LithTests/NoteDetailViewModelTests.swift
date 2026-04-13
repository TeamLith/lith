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
        let linkRepository = InMemoryLinkRepository()
        let wikiLinkService = WikiLinkService(noteRepository: repo, linkRepository: linkRepository)
        let vm = NoteDetailViewModel(noteID: note.id, repository: repo, wikiLinkService: wikiLinkService)

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
        let linkRepository = InMemoryLinkRepository()
        let wikiLinkService = WikiLinkService(noteRepository: repo, linkRepository: linkRepository)
        let vm = NoteDetailViewModel(
            noteID: note.id,
            repository: repo,
            wikiLinkService: wikiLinkService,
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
        #expect(try await linkRepository.links(from: note.id).isEmpty)
    }

    @Test("archive persists archived state")
    func archivePersistsArchivedState() async throws {
        let note = Note(title: "Archive", bodyMarkdown: "Body")
        let repo = InMemoryNoteRepository(seed: [note])
        let linkRepository = InMemoryLinkRepository()
        let wikiLinkService = WikiLinkService(noteRepository: repo, linkRepository: linkRepository)
        let vm = NoteDetailViewModel(noteID: note.id, repository: repo, wikiLinkService: wikiLinkService)

        await vm.loadNote()
        _ = await vm.archive()

        let stored = try await repo.note(id: note.id)
        #expect(stored?.isArchived == true)
        #expect(stored?.isTrashed == false)
    }

    @Test("saveNow resolves wikilinks into persisted link records")
    func saveNowPersistsResolvedWikiLinks() async throws {
        let target = Note(title: "Target", bodyMarkdown: "")
        let source = Note(title: "Source", bodyMarkdown: "")
        let repo = InMemoryNoteRepository(seed: [source, target])
        let linkRepository = InMemoryLinkRepository()
        let wikiLinkService = WikiLinkService(noteRepository: repo, linkRepository: linkRepository)
        let vm = NoteDetailViewModel(noteID: source.id, repository: repo, wikiLinkService: wikiLinkService)

        await vm.loadNote()
        vm.bodyMarkdown = "See [[Target]] and [[Target]]"
        _ = await vm.saveNow()

        let links = try await linkRepository.links(from: source.id)
        #expect(links.count == 1)
        #expect(links.first?.toNoteID == target.id)
    }

    @Test("loadNote surfaces backlink notes for presentation")
    func loadNoteSurfacesBacklinks() async {
        let target = Note(title: "Target", bodyMarkdown: "")
        let source = Note(title: "Source", bodyMarkdown: "See [[Target]]")
        let repo = InMemoryNoteRepository(seed: [source, target])
        let linkRepository = InMemoryLinkRepository(
            seed: [Link(fromNoteID: source.id, toNoteID: target.id, type: .wikilink)]
        )
        let wikiLinkService = WikiLinkService(noteRepository: repo, linkRepository: linkRepository)
        let vm = NoteDetailViewModel(noteID: target.id, repository: repo, wikiLinkService: wikiLinkService)

        await vm.loadNote()

        #expect(vm.backlinks.map(\.id) == [source.id])
    }
}

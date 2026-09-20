import Foundation
import Testing
@testable import Lith

@Suite("Markdown portability and note collections")
struct MarkdownAndNoteManagementTests {
    @Test("Export and import preserve title and body exactly including Unicode and Markdown")
    func roundTrip() throws {
        let service = MarkdownNoteService()
        for (title, body) in [("A \"quoted\" title 📝", "# Header\r\n\n- **bold**\n```swift\nlet x = 1\n```\n[[Other]]\n"), ("", ""), ("A\nB", "---\ntitle: \"Body title\"\n---\nBody")] {
            let decoded = try service.decode(service.export(title: title, body: body), filename: "changed.md")
            #expect(decoded.title == title)
            #expect(decoded.body == body)
        }
    }

    @Test("External Markdown keeps its full body and uses heading or filename as title")
    func externalMarkdown() throws {
        let service = MarkdownNoteService()
        let text = "# External\n\nContent\n"
        #expect(try service.decode(Data(text.utf8), filename: "file.md").title == "External")
        #expect(try service.decode(Data(text.utf8), filename: "file.md").body == text)
        #expect(try service.decode(Data("Plain body".utf8), filename: "Meeting.md").title == "Meeting")
        let yaml = "---\ntitle: \"Title\"\ntags: [work]\n---\nBody"
        #expect(try service.decode(Data(yaml.utf8), filename: "file.md").body == yaml)
        #expect(throws: MarkdownNoteError.self) { try service.decode(Data([0xff, 0xfe]), filename: "bad.md") }
    }

    @Test("Block parser renders headings, lists, quotes, paragraphs and fenced code without interpreting code markup")
    func blocks() {
        let markdown = "# Heading\n\nParagraph **bold**\nnext line\n\n- First\n2. Second\n> Quote\n---\n```swift\n# not a heading\n- not a list\n```"
        #expect(MarkdownBlockParser().parse(markdown) == [
            .heading(level: 1, text: "Heading"), .paragraph("Paragraph **bold**\nnext line"),
            .unorderedItem("First"), .orderedItem(number: "2", text: "Second"), .quote("Quote"), .rule,
            .code(language: "swift", text: "# not a heading\n- not a list")
        ])
        #expect(MarkdownBlockParser().parse("~~~\nunclosed code") == [.code(language: "", text: "unclosed code")])
    }

    @Test("Markdown import creates new identities and persisted backlinks")
    func importLinks() async throws {
        let target = Note(title: "Existing", bodyMarkdown: "Original")
        let collision = Note(title: "Imported", bodyMarkdown: "Keep this")
        let repository = InMemoryNoteRepository(seed: [target, collision])
        let links = InMemoryLinkRepository()
        let wiki = WikiLinkService(noteRepository: repository, linkRepository: links)
        let service = MarkdownNoteService()
        let data = Data("# Imported\nSee [[Existing]]".utf8)
        let first = try await service.importNote(data: data, filename: "existing.md", repository: repository, wikiLinkService: wiki)
        let second = try await service.importNote(data: data, filename: "existing.md", repository: repository, wikiLinkService: wiki)
        #expect(first.id != target.id && first.id != collision.id)
        #expect(first.id != second.id)
        #expect(try await repository.note(id: target.id) == target)
        #expect(try await repository.note(id: collision.id) == collision)
        #expect(try await repository.allNotes().count == 4)
        #expect(try await links.links(from: first.id).contains { $0.toNoteID == target.id })
    }

    @Test("Siri capture and append refresh persisted wikilinks")
    func captureLinks() async throws {
        let target = Note(title: "Target", bodyMarkdown: "")
        let later = Note(title: "Later", bodyMarkdown: "")
        let repository = InMemoryNoteRepository(seed: [target, later])
        let links = InMemoryLinkRepository()
        let wiki = WikiLinkService(noteRepository: repository, linkRepository: links)
        let capture = NoteCaptureService(repository: repository, wikiLinkService: wiki)
        let note = try await capture.createNote(title: "Captured", content: "[[Target]]")
        #expect(try await links.links(from: note.id).map(\.toNoteID) == [target.id])
        _ = try await capture.appendToNote(noteID: note.id, content: "[[Later]]")
        #expect(Set(try await links.links(from: note.id).map(\.toNoteID)) == [target.id, later.id])
    }

    @MainActor
    @Test("Archive and trash are independently browsable and restore preserves note attributes")
    func collectionsAndRestore() async throws {
        let active = Note(title: "Active", bodyMarkdown: "")
        let archived = Note(title: "Archived", bodyMarkdown: "Body", tags: ["tag"], source: .rss,
                            isPinned: true, isArchived: true, metadata: ["sourceURL": "https://example.com"])
        let trash = Note(title: "Trash", bodyMarkdown: "", isTrashed: true)
        let repository = InMemoryNoteRepository(seed: [active, archived, trash])
        let vm = NoteListViewModel(repository: repository)
        await vm.loadNotes()
        #expect(vm.recentNotes.map(\.id) == [active.id])
        vm.collection = .archived
        await vm.loadNotes()
        #expect(vm.pinnedNotes.map(\.id) == [archived.id])
        await vm.restore(noteID: archived.id)
        #expect(vm.pinnedNotes.isEmpty)
        let restored = try #require(await repository.note(id: archived.id))
        #expect(!restored.isArchived && !restored.isTrashed)
        #expect(restored.title == archived.title && restored.bodyMarkdown == archived.bodyMarkdown)
        #expect(restored.tags == archived.tags && restored.metadata == archived.metadata)
        #expect(restored.source == archived.source && restored.isPinned == archived.isPinned)
        #expect(restored.createdAt == archived.createdAt && restored.accessedAt == archived.accessedAt)
        vm.collection = .trashed
        await vm.loadNotes()
        #expect(vm.recentNotes.map(\.id) == [trash.id])
        await vm.restore(noteID: trash.id)
        #expect(vm.recentNotes.isEmpty)
    }

    @MainActor
    @Test("Permanent deletion rejects active notes and only removes trashed notes")
    func deletionGuard() async throws {
        let note = Note(title: "Keep", bodyMarkdown: "")
        let repository = InMemoryNoteRepository(seed: [note])
        let vm = NoteListViewModel(repository: repository)
        await vm.delete(noteID: note.id)
        #expect(vm.loadError != nil)
        #expect(try await repository.note(id: note.id) != nil)
        await vm.moveToTrash(noteID: note.id)
        await vm.delete(noteID: note.id)
        #expect(try await repository.note(id: note.id) == nil)
    }
}

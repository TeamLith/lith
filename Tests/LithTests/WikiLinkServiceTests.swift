import Foundation
import Testing
@testable import Lith

@Suite("WikiLinkService")
struct WikiLinkServiceTests {
    @Test("refreshLinks resolves note titles and backlinks exposes source notes")
    func refreshLinksResolvesBacklinks() async throws {
        let target = Note(title: "Target", bodyMarkdown: "")
        let source = Note(title: "Source", bodyMarkdown: "See [[Target]]")
        let noteRepository = InMemoryNoteRepository(seed: [source, target])
        let linkRepository = InMemoryLinkRepository()
        let service = WikiLinkService(noteRepository: noteRepository, linkRepository: linkRepository)

        let resolved = try await service.refreshLinks(for: source.id)
        let backlinks = try await service.backlinks(to: target.id)

        #expect(resolved.count == 1)
        #expect(resolved.first?.toNoteID == target.id)
        #expect(backlinks.map(\.id) == [source.id])
    }

    @Test("refreshLinks clears stale links when note content changes")
    func refreshLinksClearsStaleLinks() async throws {
        let firstTarget = Note(title: "First", bodyMarkdown: "")
        let secondTarget = Note(title: "Second", bodyMarkdown: "")
        var source = Note(title: "Source", bodyMarkdown: "See [[First]]")
        let noteRepository = InMemoryNoteRepository(seed: [source, firstTarget, secondTarget])
        let linkRepository = InMemoryLinkRepository()
        let service = WikiLinkService(noteRepository: noteRepository, linkRepository: linkRepository)

        _ = try await service.refreshLinks(for: source.id)

        source.bodyMarkdown = "See [[Second]] and [[Missing]]"
        source.updatedAt = Date().addingTimeInterval(10)
        try await noteRepository.upsert(source)
        _ = try await service.refreshLinks(for: source.id)

        let firstBacklinks = try await service.backlinks(to: firstTarget.id)
        let secondBacklinks = try await service.backlinks(to: secondTarget.id)

        #expect(firstBacklinks.isEmpty)
        #expect(secondBacklinks.map(\.id) == [source.id])
    }
}

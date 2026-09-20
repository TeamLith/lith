import Foundation
import Testing
@testable import Lith

@Suite("Graph projection")
struct GraphBuilderTests {
    private func note(_ suffix: String, title: String = "Same") -> Note {
        Note(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(suffix)")!, title: title, bodyMarkdown: "")
    }

    @Test("Global graph excludes hidden and dangling endpoints and deduplicates directed edges")
    func globalGraph() {
        let a = note("1"), b = note("2"), isolated = note("3")
        var archived = note("4"); archived.isArchived = true
        var trashed = note("5"); trashed.isTrashed = true
        let links = [
            Link(fromNoteID: a.id, toNoteID: b.id, type: .wikilink),
            Link(fromNoteID: a.id, toNoteID: b.id, type: .manual),
            Link(fromNoteID: b.id, toNoteID: a.id, type: .wikilink),
            Link(fromNoteID: a.id, toNoteID: archived.id, type: .wikilink),
            Link(fromNoteID: trashed.id, toNoteID: b.id, type: .wikilink),
            Link(fromNoteID: b.id, toNoteID: UUID(), type: .wikilink)
        ]
        let builder = GraphBuilder()
        let graph = builder.build(notes: [trashed, b, archived, isolated, a], links: links, mode: .global)
        #expect(graph.nodes.map(\.id) == [a.id, b.id, isolated.id])
        #expect(graph.nodes.map(\.degree) == [2, 2, 0])
        #expect(graph.edges == [GraphEdge(sourceID: a.id, targetID: b.id), GraphEdge(sourceID: b.id, targetID: a.id)])
        let reordered = builder.build(notes: [a, isolated, archived, b, trashed], links: links.reversed(), mode: .global)
        #expect(reordered.nodes == graph.nodes)
        #expect(reordered.edges == graph.edges)
    }

    @Test("Depth boundaries include incoming links without crossing hidden notes")
    func localDepths() {
        let a = note("1"), b = note("2"), c = note("3"), disconnected = note("4")
        var hidden = note("5"); hidden.isArchived = true
        let notes = [a, b, c, disconnected, hidden]
        let links = [
            Link(fromNoteID: b.id, toNoteID: a.id, type: .wikilink),
            Link(fromNoteID: b.id, toNoteID: c.id, type: .wikilink),
            Link(fromNoteID: c.id, toNoteID: hidden.id, type: .wikilink),
            Link(fromNoteID: hidden.id, toNoteID: disconnected.id, type: .wikilink)
        ]
        let builder = GraphBuilder()
        for depth in [-1, 0] {
            let graph = builder.build(notes: notes, links: links, mode: .local(center: a.id, depth: depth))
            #expect(graph.nodes.map(\.id) == [a.id])
            #expect(graph.nodes.first?.degree == 0)
            #expect(graph.edges.isEmpty)
        }
        let one = builder.build(notes: notes, links: links, mode: .local(center: a.id, depth: 1))
        #expect(one.nodes.map(\.id) == [a.id, b.id])
        #expect(one.edges.count == 1)
        for depth in [2, Int.max] {
            let graph = builder.build(notes: notes, links: links, mode: .local(center: a.id, depth: depth))
            #expect(graph.nodes.map(\.id) == [a.id, b.id, c.id])
            #expect(graph.edges.count == 2)
        }
        for center in [hidden.id, UUID()] {
            #expect(builder.build(notes: notes, links: links, mode: .local(center: center, depth: 2)).nodes.isEmpty)
        }
    }

    @Test("Cycles terminate and local projection includes links within the selected neighborhood")
    func cycles() {
        let a = note("1"), b = note("2"), c = note("3")
        let links = [Link(fromNoteID: a.id, toNoteID: b.id, type: .wikilink), Link(fromNoteID: b.id, toNoteID: c.id, type: .wikilink), Link(fromNoteID: c.id, toNoteID: a.id, type: .wikilink)]
        let graph = GraphBuilder().build(notes: [a, b, c], links: links, mode: .local(center: a.id, depth: 1))
        #expect(graph.nodes.count == 3)
        #expect(graph.edges.count == 3)
    }

    @Test("Repository failures are surfaced instead of returning a partial graph")
    func repositoryFailure() async {
        let service = GraphService(noteRepository: InMemoryNoteRepository(seed: [note("1")]), linkRepository: FailingGraphLinks())
        await #expect(throws: GraphTestError.self) { try await service.graph(mode: .global) }
    }

    #if canImport(CoreData)
    @Test("Graph service loads persisted links and reflects subsequent repository changes")
    func persistedGraph() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let a = note("1"), b = note("2")
        try await dependencies.noteRepository.upsert(a)
        try await dependencies.noteRepository.upsert(b)
        try await dependencies.linkRepository.replaceLinks(from: a.id, with: [Link(fromNoteID: a.id, toNoteID: b.id, type: .wikilink)])
        let service = GraphService(noteRepository: dependencies.noteRepository, linkRepository: dependencies.linkRepository)
        let graph = try await service.graph(mode: .local(center: a.id, depth: 1))
        #expect(graph.nodes.map(\.id) == [a.id, b.id])
        #expect(graph.edges.count == 1)
        try await dependencies.noteRepository.delete(noteID: b.id)
        let reloaded = try await service.graph(mode: .global)
        #expect(reloaded.nodes.map(\.id) == [a.id])
        #expect(reloaded.edges.isEmpty)
    }
    #endif
}

private enum GraphTestError: Error { case failed }
private struct FailingGraphLinks: LinkRepository {
    func replaceLinks(from sourceNoteID: UUID, with links: [Link]) async throws { throw GraphTestError.failed }
    func links() async throws -> [Link] { throw GraphTestError.failed }
    func links(from sourceNoteID: UUID) async throws -> [Link] { throw GraphTestError.failed }
    func backlinks(to targetNoteID: UUID) async throws -> [Link] { throw GraphTestError.failed }
}

import Foundation
import Testing
@testable import Lith

@MainActor
@Suite("Graph interactions")
struct GraphViewModelTests {
    @Test("Layout is deterministic with input reorderings and handles empty and single nodes")
    func layout() {
        let layout = GraphLayout()
        #expect(layout.positions(for: []).isEmpty)
        let first = GraphNode(id: UUID(), title: "First", degree: 0)
        let second = GraphNode(id: UUID(), title: "Second", degree: 1)
        #expect(layout.positions(for: [first])[first.id] == GraphPoint(x: 0, y: 0))
        let positions = layout.positions(for: [first, second])
        #expect(positions == layout.positions(for: [second, first]))
        #expect(positions[first.id] != positions[second.id])
        #expect(positions.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    @Test("Pan, bounded zoom, and reset preserve predictable coordinates")
    func viewport() {
        var viewport = GraphViewport()
        let origin = GraphPoint(x: 0, y: 0)
        #expect(viewport.project(origin, width: 800, height: 600) == GraphPoint(x: 400, y: 300))
        viewport.pan(x: 100, y: -30)
        #expect(viewport.project(origin, width: 800, height: 600) == GraphPoint(x: 500, y: 270))
        viewport.zoom(by: 100)
        #expect(viewport.scale == 4)
        viewport.zoom(by: 0.0001)
        #expect(viewport.scale == 0.25)
        viewport.zoom(by: .infinity)
        viewport.pan(x: .nan, y: 10)
        #expect(viewport.offset == GraphPoint(x: 100, y: -30))
        viewport.reset()
        #expect(viewport == GraphViewport())
    }

    @Test("Local center and depth control nodes, selection opens only visible notes")
    func localAndSelection() async throws {
        let a = Note(title: "A", bodyMarkdown: ""), b = Note(title: "B", bodyMarkdown: ""), c = Note(title: "C", bodyMarkdown: "")
        let links = InMemoryLinkRepository()
        try await links.replaceLinks(from: a.id, with: [Link(fromNoteID: a.id, toNoteID: b.id, type: .wikilink)])
        try await links.replaceLinks(from: b.id, with: [Link(fromNoteID: b.id, toNoteID: c.id, type: .wikilink)])
        let vm = GraphViewModel(service: GraphService(noteRepository: InMemoryNoteRepository(seed: [a, b, c]), linkRepository: links))
        await vm.load()
        #expect(vm.availableCenters.count == 3)
        #expect(vm.graph.nodes.count == 3)
        vm.selection.centerID = a.id
        vm.selection.depth = 0
        await vm.load()
        #expect(vm.graph.nodes.map(\.id) == [a.id])
        vm.openNote(c.id)
        #expect(vm.selectedNoteID == nil)
        vm.openNote(a.id)
        #expect(vm.selectedNoteID == a.id)
        vm.selection.depth = 1
        await vm.load()
        #expect(Set(vm.graph.nodes.map(\.id)) == [a.id, b.id])
        vm.selection.centerID = nil
        await vm.load()
        #expect(vm.graph.nodes.count == 3)
    }

    @Test("Older loads cannot replace a newer graph")
    func overlappingLoads() async {
        let service = DeferredGraphService()
        let vm = GraphViewModel(service: service)
        let old = Task { await vm.load() }
        await service.waitForRequest(0)
        let new = Task { await vm.load() }
        await service.waitForRequest(1)
        let latest = GraphNode(id: UUID(), title: "Latest", degree: 0)
        await service.finish(1, nodes: [latest])
        await new.value
        await service.finish(0, nodes: [GraphNode(id: UUID(), title: "Stale", degree: 0)])
        await old.value
        #expect(vm.graph.nodes == [latest])
        #expect(vm.availableCenters == [latest])
        #expect(!vm.isLoading)
    }

    @Test("Loading failures show errors and a retry replaces the error")
    func retry() async {
        let service = RecoveringGraphService()
        let vm = GraphViewModel(service: service)
        await vm.load()
        #expect(vm.errorMessage != nil)
        #expect(vm.graph.nodes.isEmpty)
        #expect(!vm.isLoading)
        await vm.load()
        #expect(vm.errorMessage == nil)
        #expect(vm.graph.nodes.count == 1)
    }
}

private enum GraphInteractionError: Error { case failed }
private actor RecoveringGraphService: GraphServiceProtocol {
    private var hasFailed = false
    func graph(mode: GraphMode) async throws -> NoteGraph {
        if !hasFailed { hasFailed = true; throw GraphInteractionError.failed }
        return NoteGraph(nodes: [GraphNode(id: UUID(), title: "Loaded", degree: 0)], edges: [])
    }
}

private actor DeferredGraphService: GraphServiceProtocol {
    private var counter = 0
    private var requests: [Int: CheckedContinuation<NoteGraph, Never>] = [:]
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]
    func graph(mode: GraphMode) async throws -> NoteGraph {
        let id = counter
        counter += 1
        return await withCheckedContinuation {
            requests[id] = $0
            waiters.removeValue(forKey: id)?.resume()
        }
    }
    func waitForRequest(_ id: Int) async {
        if requests[id] != nil { return }
        await withCheckedContinuation { waiters[id] = $0 }
    }
    func finish(_ id: Int, nodes: [GraphNode]) {
        requests.removeValue(forKey: id)?.resume(returning: NoteGraph(nodes: nodes, edges: []))
    }
}

import Foundation
import Observation

public struct GraphSelection: Hashable, Sendable {
    public var centerID: UUID?
    public var depth = 1
    public init() {}
}

@Observable
@MainActor
public final class GraphViewModel {
    public var selection = GraphSelection()
    public var viewport = GraphViewport()
    public var selectedNoteID: UUID?
    public private(set) var graph = NoteGraph(nodes: [], edges: [])
    public private(set) var availableCenters: [GraphNode] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    private let service: GraphServiceProtocol
    private var generation = 0

    public init(service: GraphServiceProtocol) { self.service = service }

    public func load() async {
        generation += 1
        let current = generation
        let requested = selection
        isLoading = true
        errorMessage = nil
        defer { if generation == current { isLoading = false } }
        do {
            let global = try await service.graph(mode: .global)
            let displayed: NoteGraph
            if let center = requested.centerID {
                displayed = try await service.graph(mode: .local(center: center, depth: max(0, requested.depth)))
            } else {
                displayed = global
            }
            guard generation == current, selection == requested, !Task.isCancelled else { return }
            availableCenters = global.nodes
            graph = displayed
        } catch {
            guard generation == current, selection == requested, !Task.isCancelled else { return }
            graph = NoteGraph(nodes: [], edges: [])
            errorMessage = error.localizedDescription
        }
    }

    public func openNote(_ id: UUID) {
        guard graph.nodes.contains(where: { $0.id == id }) else { return }
        selectedNoteID = id
    }
}

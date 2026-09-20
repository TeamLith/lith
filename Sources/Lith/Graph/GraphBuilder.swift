import Foundation

public struct GraphBuilder: Sendable {
    public init() {}

    /// Local traversal follows both incoming and outgoing links. Zero or negative
    /// depth returns only the center; an absent/hidden center returns an empty graph.
    public func build(notes: [Note], links: [Link], mode: GraphMode) -> NoteGraph {
        let visibleNotes = notes.filter { !$0.isArchived && !$0.isTrashed }.sorted {
            let lhs = $0.title.lowercased()
            let rhs = $1.title.lowercased()
            return lhs == rhs ? $0.id.uuidString < $1.id.uuidString : lhs < rhs
        }
        let visibleIDs = Set(visibleNotes.map(\.id))
        // Multiple persisted link kinds between the same endpoints draw one edge.
        let edges = Set(links.compactMap { link -> GraphEdge? in
            guard visibleIDs.contains(link.fromNoteID), visibleIDs.contains(link.toNoteID) else { return nil }
            return GraphEdge(sourceID: link.fromNoteID, targetID: link.toNoteID)
        }).sorted {
            if $0.sourceID != $1.sourceID { return $0.sourceID.uuidString < $1.sourceID.uuidString }
            return $0.targetID.uuidString < $1.targetID.uuidString
        }

        switch mode {
        case .global:
            return project(notes: visibleNotes, edges: edges)
        case let .local(center, depth):
            guard visibleIDs.contains(center) else { return NoteGraph(nodes: [], edges: []) }
            var adjacency: [UUID: Set<UUID>] = [:]
            for edge in edges {
                adjacency[edge.sourceID, default: []].insert(edge.targetID)
                adjacency[edge.targetID, default: []].insert(edge.sourceID)
            }
            var visited: Set<UUID> = [center]
            var frontier: Set<UUID> = [center]
            // A simple path can never visit more than N-1 hops; cap untrusted depth.
            for _ in 0..<min(max(depth, 0), max(visibleNotes.count - 1, 0)) {
                var next: Set<UUID> = []
                for node in frontier {
                    for neighbor in adjacency[node] ?? [] where visited.insert(neighbor).inserted {
                        next.insert(neighbor)
                    }
                }
                frontier = next
                if frontier.isEmpty { break }
            }
            return project(
                notes: visibleNotes.filter { visited.contains($0.id) },
                edges: edges.filter { visited.contains($0.sourceID) && visited.contains($0.targetID) }
            )
        }
    }

    private func project(notes: [Note], edges: [GraphEdge]) -> NoteGraph {
        var degree: [UUID: Int] = [:]
        for edge in edges {
            degree[edge.sourceID, default: 0] += 1
            degree[edge.targetID, default: 0] += 1
        }
        let nodes = notes.map { GraphNode(id: $0.id, title: $0.title, degree: degree[$0.id, default: 0]) }
        return NoteGraph(nodes: nodes, edges: edges)
    }
}

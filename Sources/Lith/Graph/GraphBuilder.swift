import Foundation

public struct GraphBuilder: Sendable {
    public init() {}

    public func build(notes: [Note], links: [Link], mode: GraphMode) -> NoteGraph {
        switch mode {
        case let .local(center, depth):
            return buildLocal(notes: notes, links: links, centerID: center, depth: max(depth, 1))
        case .global:
            return buildGlobal(notes: notes, links: links)
        }
    }

    private func buildLocal(notes: [Note], links: [Link], centerID: UUID, depth: Int) -> NoteGraph {
        let adjacency = adjacencyMap(links: links)
        var visited: Set<UUID> = [centerID]
        var frontier: Set<UUID> = [centerID]

        for _ in 0..<depth {
            var next: Set<UUID> = []
            for node in frontier {
                for neighbor in adjacency[node] ?? [] where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    next.insert(neighbor)
                }
            }
            frontier = next
            if frontier.isEmpty { break }
        }

        let filteredNotes = notes.filter { visited.contains($0.id) }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let filteredEdges = links
            .filter { visited.contains($0.fromNoteID) && visited.contains($0.toNoteID) }
            .map { GraphEdge(sourceID: $0.fromNoteID, targetID: $0.toNoteID) }

        return NoteGraph(nodes: nodesWithDegree(notes: filteredNotes, edges: filteredEdges), edges: filteredEdges)
    }

    private func buildGlobal(notes: [Note], links: [Link]) -> NoteGraph {
        // Bounded-force strategy placeholder: data output supports a force-layout UI layer.
        let edges = links.map { GraphEdge(sourceID: $0.fromNoteID, targetID: $0.toNoteID) }
        return NoteGraph(nodes: nodesWithDegree(notes: notes, edges: edges), edges: edges)
    }

    private func nodesWithDegree(notes: [Note], edges: [GraphEdge]) -> [GraphNode] {
        var degree: [UUID: Int] = [:]
        for edge in edges {
            degree[edge.sourceID, default: 0] += 1
            degree[edge.targetID, default: 0] += 1
        }
        return notes.map { note in
            GraphNode(id: note.id, title: note.title, degree: degree[note.id, default: 0])
        }
    }

    private func adjacencyMap(links: [Link]) -> [UUID: Set<UUID>] {
        var map: [UUID: Set<UUID>] = [:]
        for link in links {
            map[link.fromNoteID, default: []].insert(link.toNoteID)
            map[link.toNoteID, default: []].insert(link.fromNoteID)
        }
        return map
    }
}

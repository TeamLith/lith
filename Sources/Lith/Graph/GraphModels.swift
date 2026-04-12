import Foundation

public struct GraphNode: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let degree: Int

    public init(id: UUID, title: String, degree: Int) {
        self.id = id
        self.title = title
        self.degree = degree
    }
}

public struct GraphEdge: Hashable, Sendable {
    public let sourceID: UUID
    public let targetID: UUID

    public init(sourceID: UUID, targetID: UUID) {
        self.sourceID = sourceID
        self.targetID = targetID
    }
}

public struct NoteGraph: Sendable {
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]

    public init(nodes: [GraphNode], edges: [GraphEdge]) {
        self.nodes = nodes
        self.edges = edges
    }
}

public enum GraphMode: Sendable {
    case local(center: UUID, depth: Int)
    case global
}

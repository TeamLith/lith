import Foundation

public struct GraphPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// Stable circular layout, independent of repository iteration order and locale.
public struct GraphLayout: Sendable {
    public init() {}
    public func positions(for nodes: [GraphNode]) -> [UUID: GraphPoint] {
        let ordered = nodes.sorted { $0.id.uuidString < $1.id.uuidString }
        guard ordered.count > 1 else {
            return ordered.first.map { [$0.id: GraphPoint(x: 0, y: 0)] } ?? [:]
        }
        return Dictionary(uniqueKeysWithValues: ordered.enumerated().map { index, node in
            let angle = Double(index) * 2 * .pi / Double(ordered.count) - .pi / 2
            return (node.id, GraphPoint(x: cos(angle), y: sin(angle)))
        })
    }
}

public struct GraphViewport: Equatable, Sendable {
    public private(set) var scale: Double = 1
    public private(set) var offset = GraphPoint(x: 0, y: 0)
    public init() {}

    public mutating func pan(x: Double, y: Double) {
        guard x.isFinite, y.isFinite else { return }
        offset.x = min(max(offset.x + x, -100_000), 100_000)
        offset.y = min(max(offset.y + y, -100_000), 100_000)
    }

    public mutating func zoom(by factor: Double) {
        guard factor.isFinite, factor > 0 else { return }
        scale = min(max(scale * factor, 0.25), 4)
    }

    public mutating func reset() { self = Self() }

    public func project(_ point: GraphPoint, width: Double, height: Double) -> GraphPoint {
        let radius = max(0, min(width, height) / 2 - 70)
        return GraphPoint(x: width / 2 + point.x * radius * scale + offset.x,
                          y: height / 2 + point.y * radius * scale + offset.y)
    }
}

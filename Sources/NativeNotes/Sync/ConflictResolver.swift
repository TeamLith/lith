import Foundation

public struct ConflictResolutionResult: Sendable {
    public let resolved: Note?
    public let requiresManualReview: Bool

    public init(resolved: Note?, requiresManualReview: Bool) {
        self.resolved = resolved
        self.requiresManualReview = requiresManualReview
    }
}

public struct ConflictResolver: Sendable {
    public init() {}

    public func resolve(_ conflict: SyncConflict, policy: SyncConflictPolicy) -> ConflictResolutionResult {
        switch policy {
        case .lastWriterWins:
            return .init(
                resolved: conflict.local.updatedAt >= conflict.remote.updatedAt ? conflict.local : conflict.remote,
                requiresManualReview: false
            )
        case .requiresManualReview:
            return .init(resolved: nil, requiresManualReview: true)
        }
    }
}

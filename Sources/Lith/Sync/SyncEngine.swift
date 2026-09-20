import Foundation
import Observation

public struct SyncRemoteRecord: Codable, Equatable, Sendable {
    public let record: CloudRecord
    /// Transport-specific optimistic locking information, never a replacement payload.
    public let revision: Data
    public init(record: CloudRecord, revision: Data) { self.record = record; self.revision = revision }
}

public struct SyncChangePage: Sendable {
    public let records: [SyncRemoteRecord]
    public let token: Data
    public let moreComing: Bool
    public init(records: [SyncRemoteRecord], token: Data, moreComing: Bool = false) {
        self.records = records; self.token = token; self.moreComing = moreComing
    }
}

public protocol SyncTransport: Sendable {
    func accountID() async throws -> String
    func prepareZone() async throws
    func changes(since token: Data?) async throws -> SyncChangePage
    func save(_ record: CloudRecord, revision: Data?) async throws -> SyncRemoteRecord
}

public protocol SyncLocalStore: Sendable {
    func snapshot() async throws -> [CloudRecord]
    /// Compare payload/deletion state and reject concurrent edits atomically with persistence.
    func apply(_ record: CloudRecord, ifUnchanged expected: CloudRecord?) async throws
}

public struct SyncConflictCopy: Codable, Identifiable, Sendable {
    public let id: UUID
    public let detectedAt: Date
    public let local: CloudRecord
    public let remote: CloudRecord
    public init(local: CloudRecord, remote: CloudRecord, detectedAt: Date) {
        id = UUID(); self.local = local; self.remote = remote; self.detectedAt = detectedAt
    }
}

public struct SyncCheckpoint: Codable, Sendable {
    public var accountID: String?
    public var token: Data?
    public var baseline: [String: SyncRemoteRecord] = [:]
    public var pending: [String: CloudRecord] = [:]
    public var conflicts: [SyncConflictCopy] = []
    public var lastSuccessfulSync: Date?
    public var retryNotBefore: Date?
    public var manualConflicts: [String: SyncConflictCopy]? = [:]
    public init() {}
}

public protocol SyncStatePersistence: Sendable {
    func load() async throws -> SyncCheckpoint
    func save(_ checkpoint: SyncCheckpoint) async throws
}

public struct FileSyncStatePersistence: SyncStatePersistence {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() async throws -> SyncCheckpoint {
        guard FileManager.default.fileExists(atPath: url.path) else { return SyncCheckpoint() }
        return try JSONDecoder().decode(SyncCheckpoint.self, from: Data(contentsOf: url))
    }
    public func save(_ checkpoint: SyncCheckpoint) async throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(checkpoint).write(to: url, options: .atomic)
    }
}

public enum SyncEngineError: Error, LocalizedError, Sendable {
    case accountUnavailable, accountChanged, localChanged, disabled, tokenExpired
    case dependentRecords
    case retryable(String, delay: TimeInterval)
    case serverConflict(SyncRemoteRecord)
    case unsupportedEntity(String)
    case configuration(String)
    public var errorDescription: String? {
        switch self {
        case .dependentRecords: "This item still has local dependents or active audio work. Keep the local version, or finish the audio work and remove its dependents before accepting deletion."
        case .accountUnavailable: "Sign in to iCloud to sync. Your local data is available."
        case .accountChanged: "The iCloud account changed. Sync is paused to prevent mixing accounts."
        case .localChanged: "An item changed while syncing. Your edit was kept; sync again."
        case .disabled: "iCloud sync is disabled."
        case .tokenExpired: "The iCloud change history expired. Sync again to reload it."
        case .retryable(let message, _): message
        case .serverConflict: "The cloud item changed while syncing. Both copies were retained; sync again."
        case .unsupportedEntity(let name): "This version cannot sync \(name). Update Lith to continue."
        case .configuration(let message): message
        }
    }
}

public func syncContentEqual(_ lhs: CloudRecord?, _ rhs: CloudRecord?) -> Bool {
    if lhs == nil && rhs == nil { return true }
    guard let lhs, let rhs else { return false }
    return lhs.id == rhs.id && lhs.deleted == rhs.deleted && lhs.payload == rhs.payload && lhs.version == rhs.version
}

@MainActor
@Observable
public final class SyncEngine {
    public private(set) var isEnabled = false
    public private(set) var status: SyncState = .offline
    public private(set) var lastSuccessfulSync: Date?
    public private(set) var conflicts: [SyncConflictCopy] = []
    public private(set) var nextRetryAt: Date?
    public var unresolvedConflicts: [SyncConflictCopy] { Array((checkpoint.manualConflicts ?? [:]).values) }
    private let transport: SyncTransport
    private let local: SyncLocalStore
    private let persistence: SyncStatePersistence
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private var running = false
    private var checkpoint = SyncCheckpoint()

    public init(transport: SyncTransport, local: SyncLocalStore, persistence: SyncStatePersistence,
                now: @escaping @Sendable () -> Date = { Date() },
                sleep: @escaping @Sendable (TimeInterval) async throws -> Void = {
                    try await Task.sleep(for: .seconds($0))
                }) {
        self.transport = transport; self.local = local; self.persistence = persistence
        self.now = now; self.sleep = sleep
    }

    /// Restores display state without contacting iCloud, including when sync is disabled.
    public func restoreStatus() async {
        guard !running else { return }
        do {
            checkpoint = try await persistence.load()
            conflicts = checkpoint.conflicts
            lastSuccessfulSync = checkpoint.lastSuccessfulSync
            nextRetryAt = checkpoint.retryNotBefore
        } catch { status = .failed(error.localizedDescription) }
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { status = .offline }
    }

    public func synchronize() async {
        guard isEnabled, !running else { return }
        running = true
        status = .syncing
        defer { running = false }
        do {
            checkpoint = try await persistence.load()
            conflicts = checkpoint.conflicts
            lastSuccessfulSync = checkpoint.lastSuccessfulSync
            nextRetryAt = checkpoint.retryNotBefore
            if let retryAt = checkpoint.retryNotBefore, retryAt > now() {
                throw SyncEngineError.configuration("iCloud requested a pause. Try syncing after \(retryAt.formatted()).")
            }
            checkpoint.retryNotBefore = nil
            nextRetryAt = nil
            let account = try await retry { try await self.transport.accountID() }
            if let bound = checkpoint.accountID, bound != account { throw SyncEngineError.accountChanged }
            checkpoint.accountID = account
            try await persist()
            try await retry { try await self.transport.prepareZone() }
            try await refreshManualConflicts()
            var more = true
            var fetched: [SyncRemoteRecord] = []
            var nextToken = checkpoint.token
            while more {
                try ensureEnabled()
                let page: SyncChangePage
                do { page = try await retry { try await self.transport.changes(since: nextToken) } }
                catch SyncEngineError.tokenExpired {
                    checkpoint.token = nil
                    try await persist()
                    throw SyncEngineError.tokenExpired
                }
                try await checkAccount()
                fetched.append(contentsOf: page.records)
                nextToken = page.token
                more = page.moreComing
            }
            // Order across page boundaries: a feed may arrive on a later page than its articles.
            let latest = fetched.reduce(into: [String: SyncRemoteRecord]()) { $0[$1.record.id] = $1 }
            for remote in latest.values.sorted(by: Self.recordOrder) { try await reconcile(remote) }
            checkpoint.token = nextToken
            try await persist()
            let current = try await local.snapshot()
            let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
            let ids = Set(byID.keys).union(checkpoint.baseline.keys)
            for id in ids.sorted() {
                try ensureEnabled()
                let baseline = checkpoint.baseline[id]
                let value = try localCandidate(byID[id], baseline: baseline?.record)
                guard let value, !syncContentEqual(value, baseline?.record),
                      checkpoint.manualConflicts?[id] == nil else { continue }
                if value.kind == .item, let item = try? value.decode(RSSItem.self),
                   checkpoint.manualConflicts?.values.contains(where: {
                       $0.local.kind == .feed && $0.local.entityID == item.feedID
                   }) == true { continue }
                if !value.deleted, Self.noteParents(of: value).contains(where: { parent in
                    checkpoint.manualConflicts?.values.contains(where: {
                        $0.local.kind == .note && $0.local.entityID == parent
                    }) == true
                }) { continue }
                try await push(value, revision: baseline?.revision)
            }
            if !(checkpoint.manualConflicts ?? [:]).isEmpty {
                status = .failed("Some sync conflicts need review. Both versions were kept.")
                return
            }
            checkpoint.lastSuccessfulSync = now()
            try await persist()
            lastSuccessfulSync = checkpoint.lastSuccessfulSync
            status = isEnabled ? .synced : .offline
        } catch {
            status = isEnabled ? .failed(error.localizedDescription) : .offline
        }
    }

    private func reconcile(_ remote: SyncRemoteRecord) async throws {
        try remote.record.validate()
        let current = try await local.snapshot().first { $0.id == remote.record.id }
        let baseline = checkpoint.baseline[remote.record.id]?.record
        let candidate = try localCandidate(current, baseline: baseline)
        let locallyChanged = candidate != nil && !syncContentEqual(candidate, baseline)
        if let candidate, locallyChanged, !syncContentEqual(candidate, remote.record) {
            let remotelyChanged = !syncContentEqual(remote.record, baseline)
            if remotelyChanged { try await retainConflict(local: candidate, remote: remote.record) }
            if checkpoint.manualConflicts?[candidate.id] != nil ||
                (remotelyChanged && (remote.record.deleted || !Self.hasReliableClock(candidate))) {
                try await retainManualConflict(local: candidate, remote: remote)
                return
            }
            if !remotelyChanged || candidate.modifiedAt > remote.record.modifiedAt {
                try await push(candidate, revision: remote.revision)
                return
            }
        }
        if !syncContentEqual(current, remote.record), !(current == nil && remote.record.deleted) {
            try ensureEnabled()
            do { try await local.apply(remote.record, ifUnchanged: current) }
            catch SyncEngineError.dependentRecords {
                if let current { try await retainManualConflict(local: current, remote: remote) }
                return
            }
        }
        checkpoint.baseline[remote.record.id] = remote
        checkpoint.pending.removeValue(forKey: remote.record.id)
        checkpoint.manualConflicts?.removeValue(forKey: remote.record.id)
        try await persist()
    }

    private func localCandidate(_ current: CloudRecord?, baseline: CloudRecord?) throws -> CloudRecord? {
        if let current {
            if syncContentEqual(current, baseline) { return baseline }
            if let pending = checkpoint.pending[current.id], syncContentEqual(current, pending) { return pending }
            var changed = current
            // Notes carry their actual edit time. Other legacy entities lack an edit clock.
            if !Self.hasReliableClock(current) { changed.modifiedAt = now() }
            checkpoint.pending[current.id] = changed
            return changed
        }
        guard let baseline else { return nil }
        if baseline.deleted { return baseline }
        if let pending = checkpoint.pending[baseline.id], pending.deleted { return pending }
        let deleted = try baseline.tombstone(at: now())
        checkpoint.pending[baseline.id] = deleted
        return deleted
    }

    private func push(_ record: CloudRecord, revision: Data?) async throws {
        try await persist() // Persist deletion clocks and pending changes before network I/O.
        do {
            let saved = try await retry {
                // Authentication can change while backing off; validate every individual upload.
                let account = try await self.transport.accountID()
                guard account == self.checkpoint.accountID else { throw SyncEngineError.accountChanged }
                return try await self.transport.save(record, revision: revision)
            }
            checkpoint.baseline[record.id] = saved
            checkpoint.pending.removeValue(forKey: record.id)
            try await persist()
        } catch SyncEngineError.serverConflict(let server) {
            try await retainConflict(local: record, remote: server.record)
            // Never automatically resubmit with a new change tag after a race.
            throw SyncEngineError.serverConflict(server)
        }
    }

    /// Explicitly choose a retained version. Never implicitly resolve records without an edit clock.
    public func resolveConflict(_ id: UUID, keepLocal: Bool) async {
        guard isEnabled, !running,
              let conflict = checkpoint.manualConflicts?.values.first(where: { $0.id == id }) else { return }
        running = true
        status = .syncing
        defer { running = false }
        do {
            try await checkAccount()
            let current = try await local.snapshot().first { $0.id == conflict.local.id }
            guard syncContentEqual(current, conflict.local) || (current == nil && conflict.local.deleted) else {
                throw SyncEngineError.localChanged
            }
            if keepLocal {
                var value = conflict.local
                value.modifiedAt = now()
                try await push(value, revision: checkpoint.baseline[value.id]?.revision)
            } else {
                try await local.apply(conflict.remote, ifUnchanged: current)
            }
            checkpoint.manualConflicts?.removeValue(forKey: conflict.local.id)
            checkpoint.pending.removeValue(forKey: conflict.local.id)
            try await persist()
            status = .offline
        } catch { status = .failed(error.localizedDescription) }
    }

    private static func hasReliableClock(_ record: CloudRecord) -> Bool {
        if record.deleted { return false }
        if record.kind == .note || record.kind == .link { return true }
        guard record.kind == .audio || record.kind == .action,
              let object = try? JSONSerialization.jsonObject(with: record.payload) as? [String: Any],
              object["updatedAt"] is Double else { return false }
        return true
    }

    private func refreshManualConflicts() async throws {
        let snapshots = try await local.snapshot()
        for (id, conflict) in checkpoint.manualConflicts ?? [:] {
            guard let remote = checkpoint.baseline[id],
                  let current = try localCandidate(snapshots.first { $0.id == id }, baseline: remote.record) else { continue }
            if syncContentEqual(current, remote.record) {
                checkpoint.manualConflicts?.removeValue(forKey: id)
                checkpoint.pending.removeValue(forKey: id)
                try await persist()
            } else if !syncContentEqual(current, conflict.local) {
                // A user can edit while reviewing conflicts even if no new cloud events arrive.
                try await retainManualConflict(local: current, remote: remote)
            }
        }
    }

    private func retainManualConflict(local: CloudRecord, remote: SyncRemoteRecord) async throws {
        try await retainConflict(local: local, remote: remote.record)
        let copy = checkpoint.conflicts.last { $0.local == local && $0.remote == remote.record }!
        if checkpoint.manualConflicts == nil { checkpoint.manualConflicts = [:] }
        checkpoint.manualConflicts?[local.id] = copy
        checkpoint.baseline[local.id] = remote
        try await persist()
    }

    private func retainConflict(local: CloudRecord, remote: CloudRecord) async throws {
        if !checkpoint.conflicts.contains(where: { $0.local == local && $0.remote == remote }) {
            checkpoint.conflicts.append(SyncConflictCopy(local: local, remote: remote, detectedAt: now()))
            try await persist()
        }
    }
    private func persist() async throws {
        try await persistence.save(checkpoint)
        conflicts = checkpoint.conflicts
    }
    private func ensureEnabled() throws {
        try Task.checkCancellation()
        guard isEnabled else { throw SyncEngineError.disabled }
    }
    private func checkAccount() async throws {
        try ensureEnabled()
        let account = try await retry { try await self.transport.accountID() }
        guard account == checkpoint.accountID else { throw SyncEngineError.accountChanged }
    }
    private func retry<T>(_ operation: () async throws -> T) async throws -> T {
        for attempt in 0..<3 {
            try ensureEnabled()
            do { return try await operation() }
            catch SyncEngineError.retryable(let message, let delay) {
                guard attempt < 2 else { throw SyncEngineError.retryable(message, delay: delay) }
                let wait = max(delay, pow(2, Double(attempt)))
                if wait > 60 {
                    checkpoint.retryNotBefore = now().addingTimeInterval(wait)
                    nextRetryAt = checkpoint.retryNotBefore
                    try await persist()
                    throw SyncEngineError.configuration("iCloud requested a pause. Try syncing after \(nextRetryAt!.formatted()).")
                }
                try await sleep(wait)
            }
        }
        throw SyncEngineError.configuration("Sync could not finish. Try again.")
    }
    private static func recordOrder(_ lhs: SyncRemoteRecord, _ rhs: SyncRemoteRecord) -> Bool {
        func rank(_ record: CloudRecord) -> Int {
            if record.deleted { return record.kind == .feed || record.kind == .note ? 12 : 10 }
            switch record.kind { case .note, .feed: return 0; default: return 1 }
        }
        return rank(lhs.record) == rank(rhs.record) ? lhs.record.id < rhs.record.id : rank(lhs.record) < rank(rhs.record)
    }
    private static func noteParents(of record: CloudRecord) -> [UUID] {
        switch record.kind {
        case .audio: return (try? record.decode(AudioRecording.self)).map { [$0.noteID] } ?? []
        case .action: return (try? record.decode(ActionItem.self)).map { [$0.sourceNoteID] } ?? []
        case .link: return (try? record.decode(Link.self)).map { [$0.fromNoteID, $0.toNoteID] } ?? []
        default: return []
        }
    }
}

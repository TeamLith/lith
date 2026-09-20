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
    case retryable(String, delay: TimeInterval)
    case serverConflict(SyncRemoteRecord)
    case unsupportedEntity(String)
    case configuration(String)
    public var errorDescription: String? {
        switch self {
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
                guard let value, !syncContentEqual(value, baseline?.record) else { continue }
                try await push(value, revision: baseline?.revision)
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
            if !remotelyChanged || candidate.modifiedAt > remote.record.modifiedAt {
                try await push(candidate, revision: remote.revision)
                return
            }
        }
        if !syncContentEqual(current, remote.record), !(current == nil && remote.record.deleted) {
            try ensureEnabled()
            try await local.apply(remote.record, ifUnchanged: current)
        }
        checkpoint.baseline[remote.record.id] = remote
        checkpoint.pending.removeValue(forKey: remote.record.id)
        try await persist()
    }

    private func localCandidate(_ current: CloudRecord?, baseline: CloudRecord?) throws -> CloudRecord? {
        if let current {
            if syncContentEqual(current, baseline) { return baseline }
            if let pending = checkpoint.pending[current.id], syncContentEqual(current, pending) { return pending }
            var changed = current
            // Notes carry their actual edit time. Other legacy entities lack an edit clock.
            if current.kind != .note { changed.modifiedAt = now() }
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
        try await checkAccount()
        do {
            let saved = try await retry { try await self.transport.save(record, revision: revision) }
            checkpoint.baseline[record.id] = saved
            checkpoint.pending.removeValue(forKey: record.id)
            try await persist()
        } catch SyncEngineError.serverConflict(let server) {
            try await retainConflict(local: record, remote: server.record)
            // Never automatically resubmit with a new change tag after a race.
            throw SyncEngineError.serverConflict(server)
        }
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
            if record.deleted { return 10 }
            switch record.kind { case .note, .feed: return 0; default: return 1 }
        }
        return rank(lhs.record) == rank(rhs.record) ? lhs.record.id < rhs.record.id : rank(lhs.record) < rank(rhs.record)
    }
}

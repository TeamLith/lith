import Foundation
import Observation

@MainActor
public protocol SyncPreferenceStore: AnyObject {
    var isEnabled: Bool { get set }
}

@MainActor
public final class UserDefaultsSyncPreferences: SyncPreferenceStore {
    private let defaults: UserDefaults
    private let key: String
    public init(defaults: UserDefaults = .standard, key: String = "Lith.iCloudSync.enabled") {
        self.defaults = defaults; self.key = key
    }
    public var isEnabled: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

@MainActor
public final class MemorySyncPreferences: SyncPreferenceStore {
    public var isEnabled: Bool
    public init(isEnabled: Bool = false) { self.isEnabled = isEnabled }
}

@MainActor
@Observable
public final class SyncSettingsViewModel {
    public private(set) var isEnabled: Bool
    public let unavailableReason: String?
    public var isAvailable: Bool { engine != nil }
    public var isForeground: Bool { !activeScenes.isEmpty }
    public var status: SyncState { engine?.status ?? .offline }
    public var lastSuccessfulSync: Date? { engine?.lastSuccessfulSync }
    public var nextRetryAt: Date? { engine?.nextRetryAt }
    public var conflicts: [SyncConflictCopy] { engine?.conflicts ?? [] }
    public var unresolvedConflictIDs: Set<UUID> { Set(engine?.unresolvedConflicts.map(\.id) ?? []) }
    public var isSyncing: Bool { if case .syncing = status { true } else { false } }
    public var statusTitle: String {
        guard isAvailable else { return "Unavailable" }
        guard isEnabled else { return "Off — local only" }
        guard isForeground else { return "Paused in background" }
        switch status {
        case .offline: return "Offline"
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .failed: return "Needs attention"
        }
    }
    public var errorMessage: String? {
        if case .failed(let message) = status { return message }
        return nil
    }

    private let engine: SyncEngine?
    private let preferences: SyncPreferenceStore
    private let interval: TimeInterval
    private var activeScenes: Set<UUID> = []
    private var runner: Task<Void, Never>?
    private var restored = false
    private var restoration: Task<Void, Never>?

    public init(engine: SyncEngine?, preferences: SyncPreferenceStore, unavailableReason: String? = nil,
                interval: TimeInterval = 60) {
        self.engine = engine
        self.preferences = preferences
        self.unavailableReason = unavailableReason
        self.interval = max(1, interval)
        isEnabled = engine != nil && preferences.isEnabled
    }

    public func restoreStatus() async {
        guard !restored else { return }
        if let restoration { await restoration.value; return }
        let engine = self.engine
        let task = Task<Void, Never> { @MainActor in await engine?.restoreStatus() }
        restoration = task
        await task.value
        restored = true
        restoration = nil
    }

    public func setEnabled(_ enabled: Bool) {
        guard isAvailable else { return }
        isEnabled = enabled
        preferences.isEnabled = enabled
        updateRunner()
    }

    /// Each window reports its own phase; backgrounding one window must not pause another active one.
    public func setSceneActive(_ id: UUID, active: Bool) {
        if active { activeScenes.insert(id) } else { activeScenes.remove(id) }
        updateRunner()
    }

    public func syncNow() async {
        guard isEnabled, isForeground else { return }
        await restoreStatus()
        await engine?.synchronize()
    }

    public func resolve(_ conflict: SyncConflictCopy, keepLocal: Bool) async {
        guard isEnabled, isForeground else { return }
        await engine?.resolveConflict(conflict.id, keepLocal: keepLocal)
    }

    private func updateRunner() {
        let shouldRun = isEnabled && isForeground
        engine?.setEnabled(shouldRun)
        guard shouldRun else {
            runner?.cancel()
            runner = nil
            return
        }
        guard runner == nil else { return }
        runner = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.syncNow()
                let interval = self.interval
                do { try await Task.sleep(for: .seconds(interval)) }
                catch { return }
            }
        }
    }
}

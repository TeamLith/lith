import Foundation
import Testing
@testable import Lith

@MainActor
struct SyncSettingsViewModelTests {
    @Test func unavailableBuildRemainsLocalAndCannotEnable() async {
        let preferences = MemorySyncPreferences(isEnabled: true)
        let model = SyncSettingsViewModel(engine: nil, preferences: preferences, unavailableReason: "iCloud unavailable in this build")
        let scene = UUID()
        model.setSceneActive(scene, active: true)
        model.setEnabled(true)
        await model.syncNow()
        #expect(!model.isAvailable)
        #expect(!model.isEnabled)
        #expect(model.statusTitle == "Unavailable")
        #expect(model.unavailableReason?.contains("unavailable") == true)
        model.setSceneActive(scene, active: false)
    }

    @Test func enabledPreferencePersistsWhileBackgroundStopsRequests() async throws {
        let fixture = SettingsFixture()
        let scene = UUID()
        fixture.model.setSceneActive(scene, active: true)
        await fixture.model.syncNow()
        #expect(await fixture.transport.calls == 0)
        fixture.model.setEnabled(true)
        try await eventually { fixture.model.lastSuccessfulSync != nil }
        #expect(fixture.preferences.isEnabled)
        #expect(fixture.model.statusTitle == "Synced")
        fixture.model.setSceneActive(scene, active: false)
        let calls = await fixture.transport.calls
        await fixture.model.syncNow()
        #expect(await fixture.transport.calls == calls)
        #expect(fixture.preferences.isEnabled)
        #expect(!fixture.engine.isEnabled)
        #expect(fixture.model.statusTitle == "Paused in background")
        fixture.model.setEnabled(false)
        #expect(!fixture.preferences.isEnabled)
        #expect(fixture.model.statusTitle == "Off — local only")
    }

    @Test func multipleWindowsShareOneSyncLifecycle() async throws {
        let fixture = SettingsFixture()
        let first = UUID(), second = UUID()
        fixture.model.setEnabled(true)
        #expect(!fixture.engine.isEnabled)
        fixture.model.setSceneActive(first, active: true)
        fixture.model.setSceneActive(second, active: true)
        try await eventually { fixture.model.lastSuccessfulSync != nil }
        fixture.model.setSceneActive(first, active: false)
        #expect(fixture.model.isForeground)
        #expect(fixture.engine.isEnabled)
        fixture.model.setSceneActive(second, active: false)
        #expect(!fixture.model.isForeground)
        #expect(!fixture.engine.isEnabled)
    }

    @Test func recoverableFailureExposesRetryAndSuccessTimestamp() async throws {
        let fixture = SettingsFixture()
        await fixture.transport.setUnavailable(true)
        let scene = UUID()
        fixture.model.setEnabled(true)
        fixture.model.setSceneActive(scene, active: true)
        try await eventually { fixture.model.errorMessage != nil }
        #expect(fixture.model.statusTitle == "Needs attention")
        #expect(fixture.model.lastSuccessfulSync == nil)
        await fixture.transport.setUnavailable(false)
        await fixture.model.syncNow()
        #expect(fixture.model.errorMessage == nil)
        #expect(fixture.model.lastSuccessfulSync != nil)
        fixture.model.setSceneActive(scene, active: false)
    }

    @Test func restoringHistoryAndPreferenceDoesNotContactCloud() async throws {
        let transport = SettingsTransport()
        var checkpoint = SyncCheckpoint()
        let note = Note(title: "Retained", bodyMarkdown: "Text")
        let value = try CloudRecord.encode(note, kind: .note, id: note.id, modifiedAt: note.updatedAt)
        let conflict = SyncConflictCopy(local: value, remote: value, detectedAt: Date())
        checkpoint.conflicts = [conflict]
        checkpoint.manualConflicts = [value.id: conflict]
        checkpoint.lastSuccessfulSync = Date(timeIntervalSince1970: 10)
        checkpoint.retryNotBefore = Date(timeIntervalSince1970: 20)
        let engine = SyncEngine(transport: transport, local: SettingsLocalStore(), persistence: SettingsPersistence(checkpoint: checkpoint))
        let model = SyncSettingsViewModel(engine: engine, preferences: MemorySyncPreferences(isEnabled: true))
        await model.restoreStatus()
        #expect(model.isEnabled)
        #expect(!engine.isEnabled)
        #expect(await transport.calls == 0)
        #expect(model.conflicts.count == 1)
        #expect(model.unresolvedConflictIDs == [conflict.id])
        #expect(model.lastSuccessfulSync == checkpoint.lastSuccessfulSync)
        #expect(model.nextRetryAt == checkpoint.retryNotBefore)
    }

#if canImport(CoreData)
    @Test func previewContainerSharesUnavailableSettingsWithoutUserStorage() throws {
        let container = try AppDependencyContainer(mode: .inMemory)
        #expect(container.syncSettings === container.syncSettings)
        #expect(!container.syncSettings.isAvailable)
        #expect(container.syncSettings.unavailableReason?.contains("in-memory") == true)
    }
#endif
}

@MainActor private func eventually(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !condition() {
        guard ContinuousClock.now < deadline else { Issue.record("Timed out waiting for sync state"); return }
        try await Task.sleep(for: .milliseconds(1))
    }
}

@MainActor private struct SettingsFixture {
    let transport = SettingsTransport()
    let preferences = MemorySyncPreferences()
    let engine: SyncEngine
    let model: SyncSettingsViewModel
    init() {
        engine = SyncEngine(transport: transport, local: SettingsLocalStore(), persistence: SettingsPersistence())
        model = SyncSettingsViewModel(engine: engine, preferences: preferences)
    }
}
private actor SettingsTransport: SyncTransport {
    var calls = 0
    private var unavailable = false
    func setUnavailable(_ value: Bool) { unavailable = value }
    func accountID() async throws -> String {
        calls += 1
        if unavailable { throw SyncEngineError.accountUnavailable }
        return "settings-test-account"
    }
    func prepareZone() async throws {}
    func changes(since token: Data?) async throws -> SyncChangePage { SyncChangePage(records: [], token: Data([1])) }
    func save(_ record: CloudRecord, revision: Data?) async throws -> SyncRemoteRecord {
        SyncRemoteRecord(record: record, revision: Data([1]))
    }
}
private struct SettingsLocalStore: SyncLocalStore {
    func snapshot() async throws -> [CloudRecord] { [] }
    func apply(_ record: CloudRecord, ifUnchanged expected: CloudRecord?) async throws {}
}
private actor SettingsPersistence: SyncStatePersistence {
    private var checkpoint: SyncCheckpoint
    init(checkpoint: SyncCheckpoint = SyncCheckpoint()) { self.checkpoint = checkpoint }
    func load() async throws -> SyncCheckpoint { checkpoint }
    func save(_ checkpoint: SyncCheckpoint) async throws { self.checkpoint = checkpoint }
}

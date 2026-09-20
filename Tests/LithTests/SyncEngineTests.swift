import Foundation
import Testing
@testable import Lith
#if canImport(CoreData)
import CoreData

@MainActor
struct SyncEngineTests {
    @Test func disabledSyncNeverContactsCloudOrChangesLocalNotes() async throws {
        let fixture = try SyncFixture()
        let note = Note(title: "Local", bodyMarkdown: "Offline")
        try await fixture.notes.upsert(note)
        await fixture.engine.synchronize()
        #expect(await fixture.transport.calls == 0)
        #expect(try await fixture.notes.note(id: note.id) == note)
    }

    @Test func pullPushAndIncrementalTokenSurviveEngineRestart() async throws {
        let fixture = try SyncFixture()
        let local = note("Local", time: 10)
        let remote = note("Remote", time: 20)
        try await fixture.notes.upsert(local)
        await fixture.transport.seed(try record(remote))
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        #expect(try await fixture.local.snapshot().count == 2)
        #expect(await fixture.transport.allRecords().count == 2)
        #expect(fixture.engine.lastSuccessfulSync != nil)
        let restarted = fixture.makeEngine()
        restarted.setEnabled(true)
        await restarted.synchronize()
        #expect(await fixture.transport.seenTokens.last! != nil)
        #expect(try await fixture.local.snapshot().count == 2)
        #expect(await fixture.transport.saveCount == 1)
    }

    @Test func newestRemoteWinsAndConflictCopiesPersist() async throws {
        let fixture = try SyncFixture()
        let original = note("Original", time: 10)
        try await fixture.notes.upsert(original)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        let changed = note("Local edit", id: original.id, time: 30)
        try await fixture.notes.upsert(changed)
        await fixture.transport.seed(try record(note("Remote edit", id: original.id, time: 40)))
        await fixture.engine.synchronize()
        let saved = try #require(await CoreDataNoteRepository(container: fixture.container).note(id: original.id))
        #expect(saved.title == "Remote edit")
        let checkpoint = try await fixture.persistence.load()
        #expect(checkpoint.conflicts.count == 1)
        #expect(try checkpoint.conflicts[0].local.decode(Note.self).title == "Local edit")
        #expect(try checkpoint.conflicts[0].remote.decode(Note.self).title == "Remote edit")
    }

    @Test func conflictArchiveFailurePreventsOverwritingLocalEdit() async throws {
        let fixture = try SyncFixture()
        let original = note("Original", time: 10)
        try await fixture.notes.upsert(original)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        try await fixture.notes.upsert(note("Unsynced local edit", id: original.id, time: 20))
        await fixture.transport.seed(try record(note("Newer remote", id: original.id, time: 30)))
        await fixture.persistence.failConflictWrites()
        await fixture.engine.synchronize()
        #expect(try await fixture.local.snapshot().first?.decode(Note.self).title == "Unsynced local edit")
        if case .failed = fixture.engine.status {} else { Issue.record("Expected checkpoint error") }
    }

    @Test func localDeletionBecomesTombstoneAndStaleRemoteCannotResurrectIt() async throws {
        let fixture = try SyncFixture()
        let original = note("Original", time: 10)
        try await fixture.notes.upsert(original)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        try await fixture.notes.delete(noteID: original.id)
        await fixture.transport.seed(try record(note("Older remote edit", id: original.id, time: 20)))
        await fixture.engine.synchronize()
        #expect(try await fixture.local.snapshot().isEmpty)
        #expect(await fixture.transport.allRecords().first?.record.deleted == true)
        await fixture.engine.synchronize()
        #expect(try await fixture.local.snapshot().isEmpty)
        #expect(fixture.engine.conflicts.count == 1)
    }

    @Test func serverWriteRaceRetainsBothCopiesWithoutBlindRetry() async throws {
        let fixture = try SyncFixture()
        let original = note("Local", time: 10)
        try await fixture.notes.upsert(original)
        await fixture.transport.conflictOnNextSave(try record(note("Concurrent cloud", id: original.id, time: 50)))
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        #expect(await fixture.transport.saveCount == 1)
        #expect(fixture.engine.conflicts.count == 1)
        #expect(try await fixture.local.snapshot().first?.decode(Note.self).title == "Local")
        if case .failed = fixture.engine.status {} else { Issue.record("Expected visible conflict error") }
        await fixture.engine.synchronize()
        #expect(try await fixture.local.snapshot().first?.decode(Note.self).title == "Concurrent cloud")
    }

    @Test func accountSwitchStopsBeforePullOrPush() async throws {
        let fixture = try SyncFixture()
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        try await fixture.notes.upsert(note("Private account A data", time: 10))
        await fixture.transport.changeAccount("account-B")
        await fixture.engine.synchronize()
        #expect(await fixture.transport.saveCount == 0)
        #expect(try await fixture.local.snapshot().count == 1)
        #expect(try await fixture.persistence.load().accountID == "account-A")
        if case .failed(let message) = fixture.engine.status { #expect(message.contains("account changed")) }
        else { Issue.record("Expected account-change error") }
    }

    @Test func throttledTransportRetriesOnlyThreeTimes() async throws {
        let fixture = try SyncFixture()
        await fixture.transport.failAccounts(5)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        #expect(await fixture.transport.calls == 3)
        #expect(await fixture.sleeper.delays == [2, 2])
        if case .failed = fixture.engine.status {} else { Issue.record("Expected throttling error") }
    }

    @Test func longThrottlePersistsDeadlineInsteadOfRetryingTooSoon() async throws {
        let fixture = try SyncFixture()
        await fixture.transport.failAccounts(1, delay: 120)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        #expect(await fixture.transport.calls == 1)
        #expect(await fixture.sleeper.delays.isEmpty)
        #expect(fixture.engine.nextRetryAt == Date(timeIntervalSince1970: 220))
        let reopened = fixture.makeEngine()
        reopened.setEnabled(true)
        await reopened.synchronize()
        #expect(await fixture.transport.calls == 1)
    }

    @Test func expiredTokenRestartsPullWithoutDiscardingBaselinesOrLocalChanges() async throws {
        let fixture = try SyncFixture()
        let original = note("Original", time: 10)
        try await fixture.notes.upsert(original)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        await fixture.transport.expireNextToken()
        await fixture.engine.synchronize()
        #expect(try await fixture.persistence.load().token == nil)
        #expect(try await fixture.persistence.load().baseline.count == 1)
        await fixture.engine.synchronize()
        #expect(try await fixture.local.snapshot().first?.decode(Note.self) == original)
        #expect(fixture.engine.lastSuccessfulSync != nil)
    }

    @Test func staleLocalSnapshotCannotOverwriteConcurrentEditOrDelete() async throws {
        let fixture = try SyncFixture()
        let original = note("Original", time: 10)
        try await fixture.notes.upsert(original)
        let expected = try #require(await fixture.local.snapshot().first)
        let changed = note("Concurrent local edit", id: original.id, time: 40)
        try await fixture.notes.upsert(changed)
        await #expect(throws: SyncEngineError.self) {
            try await fixture.local.apply(record(note("Remote", id: original.id, time: 30)), ifUnchanged: expected)
        }
        await #expect(throws: SyncEngineError.self) {
            try await fixture.local.apply(expected.tombstone(at: Date()), ifUnchanged: expected)
        }
        #expect(try await fixture.local.snapshot().first?.decode(Note.self).title == "Concurrent local edit")
    }

    @Test func feedsAcrossPagesAreAppliedBeforeArticlesAndStateIsExact() async throws {
        let fixture = try SyncFixture()
        let feed = RSSFeed(title: "Tech", feedURL: URL(string: "https://example.com/rss")!, category: "Engineering")
        let item = RSSItem(feedID: feed.id, title: "Article", content: "Content",
                           linkURL: URL(string: "https://example.com/article")!, status: .ignored)
        // First page has an item referencing a feed in the second page.
        await fixture.transport.setPageSize(1)
        await fixture.transport.seed(try CloudRecord.encode(item, kind: .item, id: item.id, modifiedAt: Date(timeIntervalSince1970: 20)))
        await fixture.transport.seed(try CloudRecord.encode(feed, kind: .feed, id: feed.id, modifiedAt: Date(timeIntervalSince1970: 10)))
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        let rss = CoreDataRSSRepository(container: fixture.container)
        #expect(try await rss.item(id: item.id)?.status == .ignored)
        #expect(try await rss.feed(id: feed.id)?.category == "Engineering")
        #expect(await fixture.transport.saveCount == 0)
    }

    @Test func remoteTombstoneDeletesOnlyUnchangedLocalRecord() async throws {
        let fixture = try SyncFixture()
        let original = note("Original", time: 10)
        try await fixture.notes.upsert(original)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        await fixture.transport.seed(try record(original).tombstone(at: Date(timeIntervalSince1970: 50)))
        await fixture.engine.synchronize()
        #expect(try await fixture.local.snapshot().isEmpty)
        #expect(fixture.engine.conflicts.isEmpty)
    }

    @Test func fileCheckpointRetainsTokenAndConflictsAcrossReload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = FileSyncStatePersistence(url: directory.appendingPathComponent("sync.json"))
        let local = try record(note("A", time: 1))
        let remote = try record(note("B", id: local.entityID, time: 2))
        var checkpoint = SyncCheckpoint()
        checkpoint.accountID = "account-A"
        checkpoint.token = Data([1, 2, 3])
        checkpoint.conflicts = [SyncConflictCopy(local: local, remote: remote, detectedAt: Date())]
        try await persistence.save(checkpoint)
        let restored = try await persistence.load()
        #expect(restored.token == checkpoint.token)
        #expect(restored.conflicts.first?.local == local)
        #expect(restored.conflicts.first?.remote == remote)
    }
}

private func note(_ title: String, id: UUID = UUID(), time: TimeInterval) -> Note {
    Note(id: id, title: title, bodyMarkdown: title, createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: time))
}
private func record(_ note: Note) throws -> CloudRecord {
    try CloudRecord.encode(note, kind: .note, id: note.id, modifiedAt: note.updatedAt)
}

@MainActor private struct SyncFixture {
    let container: NSPersistentContainer
    let local: CoreDataSyncStore
    let notes: CoreDataNoteRepository
    let transport = TestSyncTransport()
    let persistence = MemorySyncPersistence()
    let sleeper = SyncSleeper()
    let engine: SyncEngine
    init() throws {
        container = try LithPersistentStore.makeContainer(inMemory: true)
        local = CoreDataSyncStore(container: container)
        notes = CoreDataNoteRepository(container: container)
        let sleeper = self.sleeper
        engine = SyncEngine(transport: transport, local: local, persistence: persistence,
                            now: { Date(timeIntervalSince1970: 100) }, sleep: { await sleeper.record($0) })
    }
    func makeEngine() -> SyncEngine {
        SyncEngine(transport: transport, local: local, persistence: persistence, now: { Date(timeIntervalSince1970: 100) }, sleep: { _ in })
    }
}
private actor MemorySyncPersistence: SyncStatePersistence {
    var checkpoint = SyncCheckpoint()
    private var failConflicts = false
    func failConflictWrites() { failConflicts = true }
    func load() async throws -> SyncCheckpoint { checkpoint }
    func save(_ checkpoint: SyncCheckpoint) async throws {
        if failConflicts && !checkpoint.conflicts.isEmpty { throw CocoaError(.fileWriteOutOfSpace) }
        self.checkpoint = checkpoint
    }
}
private actor SyncSleeper {
    var delays: [TimeInterval] = []
    func record(_ seconds: TimeInterval) { delays.append(seconds) }
}
private actor TestSyncTransport: SyncTransport {
    var calls = 0
    var saveCount = 0
    var seenTokens: [Data?] = []
    private var account = "account-A"
    private var failures = 0
    private var pageSize = 200
    private var retryDelay: TimeInterval = 2
    private var expireToken = false
    private var records: [String: SyncRemoteRecord] = [:]
    private var changes: [SyncRemoteRecord] = []
    private var conflictingRecord: CloudRecord?
    func accountID() async throws -> String {
        calls += 1
        if failures > 0 { failures -= 1; throw SyncEngineError.retryable("Throttled", delay: retryDelay) }
        return account
    }
    func changeAccount(_ value: String) { account = value }
    func failAccounts(_ count: Int, delay: TimeInterval = 2) { failures = count; retryDelay = delay }
    func expireNextToken() { expireToken = true }
    func setPageSize(_ count: Int) { pageSize = count }
    func conflictOnNextSave(_ value: CloudRecord) { conflictingRecord = value }
    func allRecords() -> [SyncRemoteRecord] { Array(records.values) }
    func seed(_ record: CloudRecord) {
        let remote = SyncRemoteRecord(record: record, revision: Data(String(changes.count + 1).utf8))
        records[record.id] = remote
        changes.append(remote)
    }
    func prepareZone() async throws {}
    func changes(since token: Data?) async throws -> SyncChangePage {
        seenTokens.append(token)
        if expireToken { expireToken = false; throw SyncEngineError.tokenExpired }
        let start = token.flatMap { Int(String(decoding: $0, as: UTF8.self)) } ?? 0
        let end = min(changes.count, start + pageSize)
        return SyncChangePage(records: Array(changes[start..<end]), token: Data(String(end).utf8), moreComing: end < changes.count)
    }
    func save(_ record: CloudRecord, revision: Data?) async throws -> SyncRemoteRecord {
        saveCount += 1
        if let conflictingRecord {
            self.conflictingRecord = nil
            seed(conflictingRecord)
            throw SyncEngineError.serverConflict(records[record.id]!)
        }
        if let current = records[record.id], current.revision != revision { throw SyncEngineError.serverConflict(current) }
        seed(record)
        return records[record.id]!
    }
}
#endif

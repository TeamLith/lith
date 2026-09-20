import Foundation
import Testing
@testable import Lith
#if canImport(CoreData)
import CoreData

@MainActor
struct SyncEngineTests {
    @Test func audioAndNoteTombstonesRemoveBinaryBeforeDeletingParentWithoutConflict() async throws {
        let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: files.root) }
        let fixture = try SyncFixture(audioFiles: files)
        let parent = note("Recorded", time: 10)
        try await fixture.notes.upsert(parent)
        let audio = AudioRecording(noteID: parent.id, fileURL: files.root, recordedAt: Date(timeIntervalSince1970: 10))
        let repository = CoreDataAudioRecordingRepository(container: fixture.container, files: files)
        try await repository.upsert(audio)
        let file = try files.prepare(noteID: parent.id, recordingID: audio.id)
        try Data("recorded audio".utf8).write(to: file)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        let records = try await fixture.local.snapshot()
        // Parent arrives first, but reconciliation must remove children first.
        await fixture.transport.seed(try #require(records.first { $0.kind == .note }).tombstone(at: Date()))
        await fixture.transport.seed(try #require(records.first { $0.kind == .audio }).tombstone(at: Date()))
        await fixture.engine.synchronize()
        #expect(fixture.engine.unresolvedConflicts.isEmpty)
        #expect(try await fixture.local.snapshot().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func noteTombstoneRetainsUnsyncedAudioAndActionsUntilParentIsResolved() async throws {
        let fixture = try SyncFixture()
        let parent = note("Parent", time: 10)
        try await fixture.notes.upsert(parent)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        let audio = AudioRecording(noteID: parent.id, fileURL: URL(fileURLWithPath: "/unused"))
        let action = ActionItem(sourceNoteID: parent.id, task: "Unsynced action", updatedAt: Date())
        try await CoreDataAudioRecordingRepository(container: fixture.container).upsert(audio)
        try await CoreDataActionItemRepository(container: fixture.container).upsert(action)
        await fixture.transport.seed(try record(parent).tombstone(at: Date()))
        await fixture.engine.synchronize()
        #expect(try await fixture.local.snapshot().count == 3)
        #expect(await fixture.transport.allRecords().count == 1)
        let conflict = try #require(fixture.engine.unresolvedConflicts.first)
        #expect(conflict.local.kind == .note)
        await fixture.engine.resolveConflict(conflict.id, keepLocal: true)
        await fixture.engine.synchronize()
        #expect(fixture.engine.unresolvedConflicts.isEmpty)
        #expect(await fixture.transport.allRecords().filter { !$0.record.deleted }.count == 3)
    }

    @Test func newerRemoteAudioDeletionStillRequiresReviewOfUnsyncedLocalEdit() async throws {
        let fixture = try SyncFixture()
        let parent = note("Parent", time: 10)
        try await fixture.notes.upsert(parent)
        var audio = AudioRecording(noteID: parent.id, fileURL: URL(fileURLWithPath: "/unused"), recordedAt: Date(timeIntervalSince1970: 10))
        let repository = CoreDataAudioRecordingRepository(container: fixture.container)
        try await repository.upsert(audio)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        let wire = try #require(await fixture.local.snapshot().first { $0.kind == .audio })
        audio.transcript = "Unsynced local transcript"
        audio.updatedAt = Date(timeIntervalSince1970: 20)
        try await repository.upsert(audio)
        await fixture.transport.seed(try wire.tombstone(at: Date(timeIntervalSince1970: 30)))
        await fixture.engine.synchronize()
        #expect(try await repository.recording(id: audio.id)?.transcript == audio.transcript)
        #expect(fixture.engine.unresolvedConflicts.first?.local.kind == .audio)
    }

    @Test func audioCleanupJournalRecoversCommittedDeletionButPreservesFailedTransaction() async throws {
        let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: files.root) }
        let fixture = try SyncFixture(audioFiles: files)
        let parent = note("Parent", time: 10)
        try await fixture.notes.upsert(parent)
        let audio = AudioRecording(noteID: parent.id, fileURL: files.root)
        let repository = CoreDataAudioRecordingRepository(container: fixture.container, files: files)
        try await repository.upsert(audio)
        let file = try files.prepare(noteID: parent.id, recordingID: audio.id)
        try Data("audio".utf8).write(to: file)
        let journal = SyncAudioDeletionJournal(files: files)
        // Crash before metadata commit: the pending intent must not delete audio.
        try journal.prepare(audio)
        _ = try await CoreDataSyncStore(container: fixture.container, audioFiles: files).snapshot()
        #expect(FileManager.default.fileExists(atPath: file.path))
        // Crash after metadata commit: a restarted store completes file cleanup.
        try journal.prepare(audio)
        try await repository.delete(recordingID: audio.id)
        _ = try await CoreDataSyncStore(container: fixture.container, audioFiles: files).snapshot()
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func failedCleanupIntentWritePreservesMetadataAndRecordingFile() async throws {
        let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: files.root) }
        let fixture = try SyncFixture(audioFiles: files)
        let parent = note("Parent", time: 10)
        try await fixture.notes.upsert(parent)
        let audio = AudioRecording(noteID: parent.id, fileURL: files.root)
        let repository = CoreDataAudioRecordingRepository(container: fixture.container, files: files)
        try await repository.upsert(audio)
        let file = try files.prepare(noteID: parent.id, recordingID: audio.id)
        try Data("audio".utf8).write(to: file)
        let wire = try #require(await fixture.local.snapshot().first { $0.kind == .audio })
        // An obstructing file makes durable cleanup intent creation fail.
        try Data().write(to: files.root.appendingPathComponent(".sync-deletions"))
        await #expect(throws: (any Error).self) {
            try await fixture.local.apply(wire.tombstone(at: Date()), ifUnchanged: wire)
        }
        #expect(try await repository.recording(id: audio.id) != nil)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func remoteAttachmentsRequireParentAndPreserveActualPayloadTimestamps() async throws {
        let fixture = try SyncFixture()
        let parent = note("Parent", time: 10)
        let audio = AudioRecording(noteID: parent.id, fileURL: URL(fileURLWithPath: "/unused"), recordedAt: Date(timeIntervalSince1970: 20))
        let action = ActionItem(sourceNoteID: parent.id, task: "Action", createdAt: Date(timeIntervalSince1970: 15), updatedAt: Date(timeIntervalSince1970: 30))
        let audioWire = try CloudRecord.encode(audio, kind: .audio, id: audio.id, modifiedAt: audio.updatedAt)
        let actionWire = try CloudRecord.encode(action, kind: .action, id: action.id, modifiedAt: action.updatedAt!)
        for wire in [audioWire, actionWire] {
            await #expect(throws: SyncEngineError.self) { try await fixture.local.apply(wire, ifUnchanged: nil) }
        }
        try await fixture.notes.upsert(parent)
        try await fixture.local.apply(audioWire, ifUnchanged: nil)
        try await fixture.local.apply(actionWire, ifUnchanged: nil)
        let storedAudio = try #require(await CoreDataAudioRecordingRepository(container: fixture.container).recording(id: audio.id))
        let storedAction = try #require(await CoreDataActionItemRepository(container: fixture.container).item(id: action.id))
        #expect(storedAudio.noteID == parent.id && storedAudio.updatedAt == audio.updatedAt)
        #expect(storedAction == action)
        let snapshot = try await fixture.local.snapshot()
        #expect(snapshot.first { $0.kind == .audio }?.modifiedAt == audio.updatedAt)
        #expect(snapshot.first { $0.kind == .action }?.modifiedAt == action.updatedAt)
    }

    @Test func activeAudioCannotBeDeletedAndLateUpdateCannotResurrectDeletedMetadata() async throws {
        let fixture = try SyncFixture()
        let parent = note("Parent", time: 10)
        try await fixture.notes.upsert(parent)
        var audio = AudioRecording(noteID: parent.id, fileURL: URL(fileURLWithPath: "/unused"), recordingState: .recording)
        let repository = CoreDataAudioRecordingRepository(container: fixture.container)
        try await repository.upsert(audio)
        var wire = try #require(await fixture.local.snapshot().first { $0.kind == .audio })
        await #expect(throws: SyncEngineError.self) {
            try await fixture.local.apply(wire.tombstone(at: Date()), ifUnchanged: wire)
        }
        audio.recordingState = .complete
        audio.updatedAt = audio.updatedAt.addingTimeInterval(1)
        try await repository.update(audio)
        wire = try #require(await fixture.local.snapshot().first { $0.kind == .audio })
        try await fixture.local.apply(wire.tombstone(at: Date()), ifUnchanged: wire)
        await #expect(throws: AudioRecordingPersistenceError.self) { try await repository.update(audio) }
        #expect(try await fixture.local.snapshot().allSatisfy { $0.kind != .audio })
    }

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
        let deletionConflict = try #require(fixture.engine.unresolvedConflicts.first)
        await fixture.engine.resolveConflict(deletionConflict.id, keepLocal: true)
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
        let source = try LithPersistentStore.makeContainer(inMemory: true)
        let sourceRSS = CoreDataRSSRepository(container: source)
        try await sourceRSS.addFeed(feed)
        try await sourceRSS.upsertItems([item])
        let wireRecords = try await CoreDataSyncStore(container: source).snapshot()
        await fixture.transport.setPageSize(1)
        await fixture.transport.seed(try #require(wireRecords.first { $0.kind == .item }))
        await fixture.transport.seed(try #require(wireRecords.first { $0.kind == .feed }))
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        let rss = CoreDataRSSRepository(container: fixture.container)
        #expect(try await rss.items().first?.status == .ignored)
        #expect(try await rss.feeds().first?.category == "Engineering")
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

    @Test func uploadRetryRechecksAccountAfterBackoff() async throws {
        let fixture = try SyncFixture()
        try await fixture.notes.upsert(note("Account A private note", time: 10))
        await fixture.transport.failNextSave()
        let engine = SyncEngine(transport: fixture.transport, local: fixture.local, persistence: fixture.persistence,
                                sleep: { _ in await fixture.transport.changeAccount("account-B") })
        engine.setEnabled(true)
        await engine.synchronize()
        #expect(await fixture.transport.saveCount == 1)
        #expect(await fixture.transport.allRecords().isEmpty)
        if case .failed(let message) = engine.status { #expect(message.contains("account changed")) }
        else { Issue.record("Expected account protection on retry") }
    }

    @Test func remoteFeedDeletionRetainsUnsyncedChildrenUntilExplicitResolution() async throws {
        let fixture = try SyncFixture()
        let rss = CoreDataRSSRepository(container: fixture.container)
        let feed = RSSFeed(title: "Feed", feedURL: URL(string: "https://example.com/rss")!)
        try await rss.addFeed(feed)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        let wireFeed = try #require(await fixture.transport.allRecords().first?.record)
        let child = RSSItem(feedID: feed.id, title: "Unsynced article", content: "Keep me",
                            linkURL: URL(string: "https://example.com/new")!, status: .approved)
        try await rss.upsertItems([child])
        await fixture.transport.seed(try wireFeed.tombstone(at: Date(timeIntervalSince1970: 300)))
        await fixture.engine.synchronize()
        #expect(try await rss.items().count == 1)
        #expect(try await rss.feeds().count == 1)
        let conflict = try #require(fixture.engine.unresolvedConflicts.first)
        await fixture.engine.resolveConflict(conflict.id, keepLocal: true)
        await fixture.engine.synchronize()
        #expect(fixture.engine.unresolvedConflicts.isEmpty)
        #expect(await fixture.transport.allRecords().filter { !$0.record.deleted }.count == 2)
    }

    @Test func independentlyCreatedNaturalKeysConvergeWithoutUUIDCollisions() async throws {
        let first = try SyncFixture()
        let second = try SyncFixture()
        let noteA = UUID(), noteB = UUID()
        let date = Date(timeIntervalSince1970: 10)
        for fixture in [first, second] {
            let notes = CoreDataNoteRepository(container: fixture.container)
            try await notes.upsert(Note(id: noteA, title: "A", bodyMarkdown: "[[B]]", createdAt: date, updatedAt: date))
            try await notes.upsert(Note(id: noteB, title: "B", bodyMarkdown: "", createdAt: date, updatedAt: date))
            let rss = CoreDataRSSRepository(container: fixture.container)
            let feed = RSSFeed(title: "Same Feed", feedURL: URL(string: "https://example.com/rss")!)
            try await rss.addFeed(feed)
            try await rss.upsertItems([RSSItem(feedID: feed.id, title: "Same article", content: "Body",
                linkURL: URL(string: "https://example.com/article")!, status: .approved)])
            try await CoreDataLinkRepository(container: fixture.container).replaceLinks(from: noteA,
                with: [Link(fromNoteID: noteA, toNoteID: noteB, type: .wikilink, createdAt: Date(timeIntervalSince1970: 10))])
        }
        first.engine.setEnabled(true)
        await first.engine.synchronize()
        let secondEngine = SyncEngine(transport: first.transport, local: second.local, persistence: second.persistence)
        secondEngine.setEnabled(true)
        await secondEngine.synchronize()
        #expect(try await first.local.snapshot().count == 5)
        #expect(try await second.local.snapshot().count == 5)
        #expect(await first.transport.allRecords().count == 5)
        #expect(secondEngine.unresolvedConflicts.isEmpty)
        let rss = CoreDataRSSRepository(container: second.container)
        #expect(try await rss.items().first?.status == .approved)
        let storedFeeds = try await rss.feeds()
        #expect(try await rss.items().first?.feedID == storedFeeds.first?.id)
    }

    @Test func canonicalRSSReferencesTranslateBackToExistingLocalIDs() async throws {
        let fixture = try SyncFixture()
        let rss = CoreDataRSSRepository(container: fixture.container)
        let feed = RSSFeed(title: "Feed", feedURL: URL(string: "https://example.com/rss")!)
        let item = RSSItem(feedID: feed.id, title: "Article", content: "Body", linkURL: URL(string: "https://example.com/article")!)
        try await rss.addFeed(feed)
        try await rss.upsertItems([item])
        let canonicalFeed = SyncIdentity.feed(feed.feedURL)
        let canonicalItem = SyncIdentity.item(feedID: canonicalFeed, url: item.linkURL)
        let imported = Note(title: "Imported note", bodyMarkdown: "Body", source: .rss,
                            metadata: ["rssFeedID": canonicalFeed.uuidString, "rssItemID": canonicalItem.uuidString])
        try await fixture.local.apply(record(imported), ifUnchanged: nil)
        let stored = try #require(await fixture.notes.note(id: imported.id))
        #expect(stored.metadata["rssFeedID"] == feed.id.uuidString)
        #expect(stored.metadata["rssItemID"] == item.id.uuidString)
        let exported = try #require(await fixture.local.snapshot().first { $0.kind == .note })
        #expect(try exported.decode(Note.self).metadata["rssFeedID"] == canonicalFeed.uuidString)
        #expect(try exported.decode(Note.self).metadata["rssItemID"] == canonicalItem.uuidString)
    }

    @Test func legacyFeedConflictRequiresChoiceInsteadOfUsingSyncTimeAsEditTime() async throws {
        let fixture = try SyncFixture()
        let rss = CoreDataRSSRepository(container: fixture.container)
        var feed = RSSFeed(title: "Feed", feedURL: URL(string: "https://example.com/rss")!, category: "Original")
        try await rss.addFeed(feed)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        let initial = try #require(await fixture.transport.allRecords().first?.record)
        feed.category = "Old offline edit"
        try await rss.addFeed(feed)
        var remoteFeed = try initial.decode(RSSFeed.self)
        remoteFeed.category = "Newer cloud edit"
        await fixture.transport.seed(try .encode(remoteFeed, kind: .feed, id: remoteFeed.id, modifiedAt: Date(timeIntervalSince1970: 90)))
        await fixture.engine.synchronize()
        #expect(fixture.engine.unresolvedConflicts.count == 1)
        #expect(try await rss.feeds().first?.category == "Old offline edit")
        #expect(try await fixture.transport.allRecords().first?.record.decode(RSSFeed.self).category == "Newer cloud edit")
        await fixture.engine.resolveConflict(fixture.engine.unresolvedConflicts[0].id, keepLocal: false)
        #expect(try await CoreDataRSSRepository(container: fixture.container).feeds().first?.category == "Newer cloud edit")
    }

    @Test func editingAnUnresolvedConflictRefreshesItsSnapshotWithoutNewCloudEvents() async throws {
        let fixture = try SyncFixture()
        let rss = CoreDataRSSRepository(container: fixture.container)
        var feed = RSSFeed(title: "Feed", feedURL: URL(string: "https://example.com/rss")!, category: "Original")
        try await rss.addFeed(feed)
        fixture.engine.setEnabled(true)
        await fixture.engine.synchronize()
        let original = try #require(await fixture.transport.allRecords().first?.record)
        feed.category = "Local edit"
        try await rss.addFeed(feed)
        var remote = try original.decode(RSSFeed.self)
        remote.category = "Remote edit"
        await fixture.transport.seed(try .encode(remote, kind: .feed, id: remote.id, modifiedAt: Date(timeIntervalSince1970: 90)))
        await fixture.engine.synchronize()
        let staleID = try #require(fixture.engine.unresolvedConflicts.first?.id)
        feed.category = "Local correction during review"
        try await rss.addFeed(feed)
        await fixture.engine.synchronize()
        let refreshed = try #require(fixture.engine.unresolvedConflicts.first)
        #expect(refreshed.id != staleID)
        #expect(try refreshed.local.decode(RSSFeed.self).category == "Local correction during review")
        await fixture.engine.resolveConflict(refreshed.id, keepLocal: true)
        #expect(fixture.engine.unresolvedConflicts.isEmpty)
        #expect(try await fixture.transport.allRecords().first?.record.decode(RSSFeed.self).category == "Local correction during review")
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
    init(audioFiles: AudioFileStore? = nil) throws {
        container = try LithPersistentStore.makeContainer(inMemory: true)
        local = CoreDataSyncStore(container: container, audioFiles: audioFiles)
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
    private var failSave = false
    func failNextSave() { failSave = true }
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
        if failSave { failSave = false; throw SyncEngineError.retryable("Temporary upload failure", delay: 1) }
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

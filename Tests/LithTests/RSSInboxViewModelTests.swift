import Foundation
import Testing
@testable import Lith

@MainActor
struct RSSInboxViewModelTests {
    @Test func approvalDoesNotCreateNoteAndSaveRetainsSourceLinkage() async throws {
        let feed = RSSFeed(title: "Engineering", feedURL: URL(string: "https://example.com/feed")!, category: "Tech")
        let article = RSSItem(feedID: feed.id, title: "Article", content: "Article text", author: "Writer",
                              linkURL: URL(string: "https://example.com/article")!)
        let rss = InMemoryRSSRepository(seedFeeds: [feed], seedItems: [article])
        let notes = InMemoryNoteRepository()
        let model = RSSInboxViewModel(repository: rss, noteRepository: notes, fetchService: EmptyRSSFetcher())
        await model.load()
        #expect(model.groups.first?.title == "Tech / Engineering")
        #expect(await model.saveAsNote(itemID: article.id) == nil)
        #expect(try await notes.allNotes().isEmpty)
        await model.setStatus(.approved, itemID: article.id)
        #expect(try await rss.item(id: article.id)?.status == .approved)
        #expect(try await notes.allNotes().isEmpty)
        let noteID = try #require(await model.saveAsNote(itemID: article.id, commentary: "Keep this"))
        let note = try #require(try await notes.note(id: noteID))
        #expect(note.source == .rss)
        #expect(note.metadata["sourceURL"] == article.linkURL.absoluteString)
        #expect(note.metadata["rssItemID"] == article.id.uuidString)
        #expect(note.metadata["rssFeedID"] == feed.id.uuidString)
        #expect(note.metadata["author"] == "Writer")
        #expect(note.tags == ["rss", "tech"])
        #expect(note.bodyMarkdown.contains("Keep this"))
        #expect(try await rss.item(id: article.id)?.savedNoteID == noteID)
        #expect(try await rss.item(id: article.id)?.status == .savedAsNote)
        #expect(await model.saveAsNote(itemID: article.id) == noteID)
        #expect(try await notes.allNotes().count == 1)
        await model.setStatus(.new, itemID: article.id)
        #expect(try await rss.item(id: article.id)?.status == .savedAsNote)
    }

    @Test func ignoredItemsCanReturnToNewWithoutRefreshResettingState() async throws {
        let feed = RSSFeed(title: "Feed", feedURL: URL(string: "https://example.com/feed")!)
        let article = RSSItem(feedID: feed.id, title: "Article", content: "Text", linkURL: URL(string: "https://example.com/a")!)
        let rss = InMemoryRSSRepository(seedFeeds: [feed], seedItems: [article])
        let model = RSSInboxViewModel(repository: rss, noteRepository: InMemoryNoteRepository(), fetchService: EmptyRSSFetcher())
        await model.setStatus(.ignored, itemID: article.id)
        try await rss.upsertItems([article])
        #expect(try await rss.item(id: article.id)?.status == .ignored)
        model.statusFilter = .ignored
        await model.load()
        #expect(model.groups.first?.items.count == 1)
        await model.setStatus(.new, itemID: article.id)
        #expect(try await rss.item(id: article.id)?.status == .new)
        #expect(model.groups.first?.items.isEmpty == true)
    }

    @Test func feedInputValidationAndDuplicateHandling() async throws {
        let rss = InMemoryRSSRepository()
        let model = RSSInboxViewModel(repository: rss, noteRepository: InMemoryNoteRepository(), fetchService: EmptyRSSFetcher())
        #expect(await model.addFeed(url: "file:///private/feed.xml", title: "", category: "") == false)
        #expect(await model.addFeed(url: "https://user:password@example.com/rss", title: "", category: "") == false)
        #expect(try await rss.feeds().isEmpty)
        #expect(await model.addFeed(url: " https://EXAMPLE.com/feed#fragment ", title: " Tech ", category: " News "))
        #expect(await model.addFeed(url: "https://example.com/feed", title: "Replacement", category: ""))
        let feed = try #require(try await rss.feeds().first)
        #expect(try await rss.feeds().count == 1)
        #expect(feed.title == "Tech")
        #expect(feed.category == "News")
        #expect(feed.feedURL.absoluteString == "https://example.com/feed")
    }

    @Test func retryAfterItemWriteFailureReusesSavedNoteWithoutOverwritingEdits() async throws {
        let feed = RSSFeed(title: "Feed", feedURL: URL(string: "https://example.com/feed")!)
        let article = RSSItem(feedID: feed.id, title: "Article", content: "Text",
                              linkURL: URL(string: "https://example.com/a")!, status: .approved)
        let rss = FailingWorkflowRSSRepository(base: InMemoryRSSRepository(seedFeeds: [feed], seedItems: [article]))
        let notes = InMemoryNoteRepository()
        let model = RSSInboxViewModel(repository: rss, noteRepository: notes, fetchService: EmptyRSSFetcher())
        #expect(await model.saveAsNote(itemID: article.id) == nil)
        #expect(model.error != nil)
        #expect(try await rss.item(id: article.id)?.status == .approved)
        var note = try #require(try await notes.allNotes().first)
        note.bodyMarkdown += "\nUser edit after interrupted save"
        try await notes.upsert(note)
        // Recreate the model to demonstrate recovery after an app restart.
        let reopened = RSSInboxViewModel(repository: rss, noteRepository: notes, fetchService: EmptyRSSFetcher())
        #expect(await reopened.saveAsNote(itemID: article.id) == note.id)
        #expect(try await notes.allNotes().count == 1)
        #expect(try await notes.note(id: note.id)?.bodyMarkdown.contains("User edit") == true)
        #expect(try await rss.item(id: article.id)?.savedNoteID == note.id)
    }

    @Test func failedNoteWriteLeavesArticleApprovedForRetry() async throws {
        let feed = RSSFeed(title: "Feed", feedURL: URL(string: "https://example.com/feed")!)
        let article = RSSItem(feedID: feed.id, title: "Article", content: "Text",
                              linkURL: URL(string: "https://example.com/a")!, status: .approved)
        let rss = InMemoryRSSRepository(seedFeeds: [feed], seedItems: [article])
        let model = RSSInboxViewModel(repository: rss, noteRepository: FailingNoteWriter(), fetchService: EmptyRSSFetcher())
        #expect(await model.saveAsNote(itemID: article.id) == nil)
        #expect(model.error != nil)
        #expect(try await rss.item(id: article.id)?.status == .approved)
        #expect(try await rss.item(id: article.id)?.savedNoteID == nil)
    }
}

private struct EmptyRSSFetcher: RSSFetchServiceProtocol {
    func refreshAllFeeds() async throws -> RSSRefreshReport {
        RSSRefreshReport(startedAt: Date(), completedAt: Date(), results: [])
    }
}

private enum InboxTestError: Error { case storageFailure }

private actor FailingNoteWriter: NoteRepository {
    func updateExisting(_ note: Note, expected: Note) async throws { try await upsert(note) }
    func upsert(_ note: Note) async throws { throw InboxTestError.storageFailure }
    func delete(noteID: UUID) async throws {}
    func allNotes() async throws -> [Note] { [] }
    func note(id: UUID) async throws -> Note? { nil }
}

private actor FailingWorkflowRSSRepository: RSSRepository {
    let base: InMemoryRSSRepository
    var failNextSave = true
    init(base: InMemoryRSSRepository) { self.base = base }
    func addFeed(_ feed: RSSFeed) async throws { try await base.addFeed(feed) }
    func feeds() async throws -> [RSSFeed] { try await base.feeds() }
    func feed(id: UUID) async throws -> RSSFeed? { try await base.feed(id: id) }
    func updateLastFetchedAt(for feedID: UUID, to date: Date?) async throws { try await base.updateLastFetchedAt(for: feedID, to: date) }
    func upsertItems(_ items: [RSSItem]) async throws { try await base.upsertItems(items) }
    func items(feedID: UUID?) async throws -> [RSSItem] { try await base.items(feedID: feedID) }
    func item(id: UUID) async throws -> RSSItem? { try await base.item(id: id) }
    func updateItemWorkflow(itemID: UUID, status: RSSItemStatus, savedNoteID: UUID?) async throws {
        if status == .savedAsNote && failNextSave {
            failNextSave = false
            throw InboxTestError.storageFailure
        }
        try await base.updateItemWorkflow(itemID: itemID, status: status, savedNoteID: savedNoteID)
    }
}

#if canImport(CoreData)
@Test func coreDataRSSWorkflowResetAndSavedLinkSurviveRepositoryReload() async throws {
    let container = try LithPersistentStore.makeContainer(inMemory: true)
    let repository = CoreDataRSSRepository(container: container)
    let feed = RSSFeed(title: "Feed", feedURL: URL(string: "https://example.com/feed")!)
    let item = RSSItem(feedID: feed.id, title: "Article", content: "Text",
                       linkURL: URL(string: "https://example.com/a")!, status: .ignored)
    try await repository.addFeed(feed)
    try await repository.upsertItems([item])
    try await repository.updateItemWorkflow(itemID: item.id, status: .new, savedNoteID: nil)
    let reopened = CoreDataRSSRepository(container: container)
    #expect(try await reopened.item(id: item.id)?.status == .new)
    let noteID = UUID()
    try await repository.updateItemWorkflow(itemID: item.id, status: .savedAsNote, savedNoteID: noteID)
    let reread = CoreDataRSSRepository(container: container)
    #expect(try await reread.item(id: item.id)?.savedNoteID == noteID)
}
#endif

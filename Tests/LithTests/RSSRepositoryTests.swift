import Foundation
import Testing
@testable import Lith

@Test func parsedRSSFeedMapsToDomainFeed() {
    let parsedFeed = ParsedRSSFeed(
        title: "Engineering Weekly",
        feedURL: URL(string: "https://example.com/feed.xml")!,
        category: "Tech"
    )

    let feed = RSSFeed(parsedFeed: parsedFeed, refreshIntervalSeconds: 1_800)

    #expect(feed.title == "Engineering Weekly")
    #expect(feed.feedURL == URL(string: "https://example.com/feed.xml")!)
    #expect(feed.category == "Tech")
    #expect(feed.refreshIntervalSeconds == 1_800)
    #expect(feed.isActive == true)
}

@Test func parsedRSSItemMapsToDomainItem() {
    let feedID = UUID()
    let publishedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let parsedItem = ParsedRSSItem(
        title: "Swift 6.2",
        content: "Release notes",
        author: "Apple",
        publishedAt: publishedAt,
        linkURL: URL(string: "https://example.com/swift-6-2")!
    )

    let item = RSSItem(parsedItem: parsedItem, feedID: feedID)

    #expect(item.feedID == feedID)
    #expect(item.title == "Swift 6.2")
    #expect(item.content == "Release notes")
    #expect(item.author == "Apple")
    #expect(item.publishedAt == publishedAt)
    #expect(item.linkURL == URL(string: "https://example.com/swift-6-2")!)
    #expect(item.status == .new)
    #expect(item.savedNoteID == nil)
}

@Test func inMemoryRSSRepositoryDeduplicatesItemsByFeedAndLink() async throws {
    let repository = InMemoryRSSRepository()
    let feed = RSSFeed(title: "Engineering", feedURL: URL(string: "https://example.com/feed.xml")!)

    try await repository.addFeed(feed)

    let original = RSSItem(
        id: UUID(),
        feedID: feed.id,
        title: "Swift 6",
        content: "v1",
        publishedAt: Date(timeIntervalSince1970: 100),
        linkURL: URL(string: "https://example.com/swift6")!,
        status: .approved,
        savedNoteID: UUID()
    )
    let refreshed = RSSItem(
        id: UUID(),
        feedID: feed.id,
        title: "Swift 6 updated",
        content: "v2",
        publishedAt: Date(timeIntervalSince1970: 200),
        linkURL: original.linkURL
    )

    try await repository.upsertItems([original])
    try await repository.upsertItems([refreshed])

    let items = try await repository.items(feedID: feed.id)
    #expect(items.count == 1)
    #expect(items[0].id == original.id)
    #expect(items[0].title == "Swift 6 updated")
    #expect(items[0].content == "v2")
    #expect(items[0].status == .approved)
    #expect(items[0].savedNoteID == original.savedNoteID)
}

#if canImport(CoreData)
import CoreData

@available(macOS 10.15, iOS 13.0, *)
@Test func coreDataRSSRepositoryAddsListsAndUpdatesFeeds() async throws {
    let repository = CoreDataRSSRepository(container: try LithPersistentStore.makeContainer(inMemory: true))
    let feed = RSSFeed(
        title: "Engineering",
        feedURL: URL(string: "https://example.com/feed.xml")!,
        category: "Tech",
        refreshIntervalSeconds: 7_200
    )
    let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)

    try await repository.addFeed(feed)
    try await repository.updateLastFetchedAt(for: feed.id, to: fetchedAt)

    let feeds = try await repository.feeds()
    let storedFeed = try #require(feeds.first)

    #expect(feeds.count == 1)
    #expect(storedFeed.id == feed.id)
    #expect(storedFeed.title == "Engineering")
    #expect(storedFeed.category == "Tech")
    #expect(storedFeed.refreshIntervalSeconds == 7_200)
    #expect(storedFeed.lastFetchedAt == fetchedAt)
}

@available(macOS 10.15, iOS 13.0, *)
@Test func coreDataRSSRepositoryDeduplicatesAndPreservesWorkflowState() async throws {
    let repository = CoreDataRSSRepository(container: try LithPersistentStore.makeContainer(inMemory: true))
    let feed = RSSFeed(title: "Engineering", feedURL: URL(string: "https://example.com/feed.xml")!)
    let savedNoteID = UUID()

    try await repository.addFeed(feed)

    let original = RSSItem(
        id: UUID(),
        feedID: feed.id,
        title: "Swift 6",
        content: "v1",
        author: "Apple",
        publishedAt: Date(timeIntervalSince1970: 100),
        linkURL: URL(string: "https://example.com/swift6")!,
        status: .savedAsNote,
        savedNoteID: savedNoteID
    )
    let refreshed = RSSItem(
        id: UUID(),
        feedID: feed.id,
        title: "Swift 6 refreshed",
        content: "v2",
        author: "Apple News",
        publishedAt: Date(timeIntervalSince1970: 200),
        linkURL: original.linkURL
    )

    try await repository.upsertItems([original])
    try await repository.upsertItems([refreshed])

    let items = try await repository.items(feedID: feed.id)
    let storedItem = try #require(items.first)

    #expect(items.count == 1)
    #expect(storedItem.id == original.id)
    #expect(storedItem.title == "Swift 6 refreshed")
    #expect(storedItem.content == "v2")
    #expect(storedItem.author == "Apple News")
    #expect(storedItem.status == .savedAsNote)
    #expect(storedItem.savedNoteID == savedNoteID)
}
#endif

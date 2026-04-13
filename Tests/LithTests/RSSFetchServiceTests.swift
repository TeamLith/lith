import Foundation
import Testing
@testable import Lith

@Suite("RSSFetchService")
struct RSSFetchServiceTests {
    @Test("FeedKit parser maps RSS documents into feed and item snapshots")
    func feedKitParserMapsRSSDocument() throws {
        let parser = FeedKitRSSFeedParser()
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Engineering Weekly</title>
            <category>Tech</category>
            <item>
              <title>Swift 6.2</title>
              <link>https://example.com/swift-6-2</link>
              <description>Release notes</description>
              <author>Apple</author>
              <pubDate>Tue, 14 Nov 2023 12:00:00 GMT</pubDate>
            </item>
          </channel>
        </rss>
        """

        let parsed = try parser.parse(data: Data(xml.utf8), sourceURL: feedURL)
        let item = try #require(parsed.items.first)

        #expect(parsed.feed.title == "Engineering Weekly")
        #expect(parsed.feed.category == "Tech")
        #expect(item.title == "Swift 6.2")
        #expect(item.content == "Release notes")
        #expect(item.author == "Apple")
        #expect(item.linkURL == URL(string: "https://example.com/swift-6-2")!)
        #expect(item.publishedAt != nil)
    }

    @Test("FeedKit parser resolves relative RSS item links against the feed URL")
    func feedKitParserResolvesRelativeRSSItemLinks() throws {
        let parser = FeedKitRSSFeedParser()
        let feedURL = URL(string: "https://example.com/feeds/engineering.xml")!
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Engineering Weekly</title>
            <item>
              <title>Swift 6.2</title>
              <link>/posts/swift-6-2</link>
              <description>Release notes</description>
            </item>
          </channel>
        </rss>
        """

        let parsed = try parser.parse(data: Data(xml.utf8), sourceURL: feedURL)
        let item = try #require(parsed.items.first)

        #expect(item.linkURL == URL(string: "https://example.com/posts/swift-6-2")!)
    }

    @Test("FeedKit parser rejects opaque RSS GUIDs when no item link is present")
    func feedKitParserRejectsOpaqueRSSGUIDFallbacks() throws {
        let parser = FeedKitRSSFeedParser()
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Engineering Weekly</title>
            <item>
              <title>Swift 6.2</title>
              <guid isPermaLink="false">abc123</guid>
              <description>Release notes</description>
            </item>
          </channel>
        </rss>
        """

        let parsed = try parser.parse(data: Data(xml.utf8), sourceURL: feedURL)

        #expect(parsed.items.isEmpty)
    }

    @Test("refreshAllFeeds stores parsed items and stamps lastFetchedAt")
    func refreshAllFeedsStoresItemsAndUpdatesFeedMetadata() async throws {
        let repository = InMemoryRSSRepository()
        let feed = RSSFeed(title: "Engineering", feedURL: URL(string: "https://example.com/feed.xml")!)
        try await repository.addFeed(feed)

        let service = RSSFetchService(
            repository: repository,
            dataLoader: LoaderStub(mode: .success(Data("ignored".utf8))),
            parser: ParserStub(
                mode: .success(
                    ParsedRSSDocument(
                        feed: ParsedRSSFeed(
                            title: "Engineering Weekly",
                            feedURL: feed.feedURL,
                            category: "Tech"
                        ),
                        items: [
                            ParsedRSSItem(
                                title: "Swift 6.2",
                                content: "Release notes",
                                author: "Apple",
                                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                linkURL: URL(string: "https://example.com/swift-6-2")!
                            )
                        ]
                    )
                )
            )
        )

        let report = try await service.refreshAllFeeds()
        let storedFeed = try #require(await repository.feed(id: feed.id))
        let items = try await repository.items(feedID: feed.id)

        #expect(report.refreshedFeedCount == 1)
        #expect(report.failedFeedCount == 0)
        #expect(report.processedItemCount == 1)
        #expect(items.count == 1)
        #expect(items[0].title == "Swift 6.2")
        #expect(storedFeed.title == "Engineering Weekly")
        #expect(storedFeed.category == "Tech")
        #expect(storedFeed.lastFetchedAt != nil)
    }

    @Test("refreshAllFeeds reports malformed feeds as non-retryable")
    func refreshAllFeedsReportsMalformedFeedFailure() async throws {
        let repository = InMemoryRSSRepository()
        let feed = RSSFeed(title: "Broken", feedURL: URL(string: "https://example.com/broken.xml")!)
        try await repository.addFeed(feed)

        let service = RSSFetchService(
            repository: repository,
            dataLoader: LoaderStub(mode: .success(Data("invalid".utf8))),
            parser: ParserStub(mode: .malformed)
        )

        let report = try await service.refreshAllFeeds()
        let failure = try #require(report.failures.first)
        let storedFeed = try #require(await repository.feed(id: feed.id))

        #expect(report.refreshedFeedCount == 0)
        #expect(report.failedFeedCount == 1)
        #expect(failure.error?.isRetryable == false)
        #expect(storedFeed.lastFetchedAt == nil)

        guard case let .malformedFeed(feedURL, reason)? = failure.error else {
            Issue.record("Expected a malformed-feed failure.")
            return
        }

        #expect(feedURL == feed.feedURL)
        #expect(!reason.isEmpty)
    }

    @Test("refreshAllFeeds reports retryable network failures")
    func refreshAllFeedsReportsRetryableNetworkFailure() async throws {
        let repository = InMemoryRSSRepository()
        let feed = RSSFeed(title: "Engineering", feedURL: URL(string: "https://example.com/feed.xml")!)
        try await repository.addFeed(feed)

        let service = RSSFetchService(
            repository: repository,
            dataLoader: LoaderStub(mode: .failure(URLError(.timedOut))),
            parser: ParserStub(mode: .success(.init(feed: ParsedRSSFeed(title: "Unused", feedURL: feed.feedURL), items: [])))
        )

        let report = try await service.refreshAllFeeds()
        let failure = try #require(report.failures.first)
        let storedFeed = try #require(await repository.feed(id: feed.id))

        #expect(report.refreshedFeedCount == 0)
        #expect(report.failedFeedCount == 1)
        #expect(failure.error?.isRetryable == true)
        #expect(storedFeed.lastFetchedAt == nil)

        guard case let .network(feedURL, reason, retryable)? = failure.error else {
            Issue.record("Expected a network failure.")
            return
        }

        #expect(feedURL == feed.feedURL)
        #expect(!reason.isEmpty)
        #expect(retryable == true)
    }
}

private struct LoaderStub: RSSFeedDataLoading {
    enum Mode {
        case success(Data)
        case failure(URLError)
    }

    let mode: Mode

    func loadData(from url: URL) async throws -> Data {
        switch mode {
        case let .success(data):
            return data
        case let .failure(error):
            throw error
        }
    }
}

private struct ParserStub: RSSFeedParsing {
    enum Mode {
        case success(ParsedRSSDocument)
        case malformed
    }

    let mode: Mode

    func parse(data: Data, sourceURL: URL) throws -> ParsedRSSDocument {
        switch mode {
        case let .success(document):
            return document
        case .malformed:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "The data isn’t in the correct format.")
            )
        }
    }
}

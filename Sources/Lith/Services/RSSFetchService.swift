import FeedKit
import Foundation
import OSLog

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum RSSFetchError: Error, Hashable, Sendable {
    case network(feedURL: URL, reason: String, retryable: Bool)
    case malformedFeed(feedURL: URL, reason: String)
    case storage(feedURL: URL, reason: String)

    public var isRetryable: Bool {
        switch self {
        case let .network(_, _, retryable):
            return retryable
        case .malformedFeed, .storage:
            return false
        }
    }
}

extension RSSFetchError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .network(_, reason, retryable):
            return retryable ? "The feed could not be refreshed yet: \(reason)" : "The feed request failed: \(reason)"
        case let .malformedFeed(_, reason):
            return "The feed contents could not be parsed: \(reason)"
        case let .storage(_, reason):
            return "The fetched feed could not be stored: \(reason)"
        }
    }
}

public struct RSSFeedRefreshResult: Identifiable, Hashable, Sendable {
    public let feedID: UUID
    public let feedTitle: String
    public let feedURL: URL
    public let processedItemCount: Int
    public let refreshedAt: Date?
    public let error: RSSFetchError?

    public var id: UUID { feedID }
    public var isSuccess: Bool { error == nil }

    public init(
        feedID: UUID,
        feedTitle: String,
        feedURL: URL,
        processedItemCount: Int,
        refreshedAt: Date?,
        error: RSSFetchError?
    ) {
        self.feedID = feedID
        self.feedTitle = feedTitle
        self.feedURL = feedURL
        self.processedItemCount = processedItemCount
        self.refreshedAt = refreshedAt
        self.error = error
    }
}

public struct RSSRefreshReport: Hashable, Sendable {
    public let startedAt: Date
    public let completedAt: Date
    public let results: [RSSFeedRefreshResult]

    public init(startedAt: Date, completedAt: Date, results: [RSSFeedRefreshResult]) {
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.results = results
    }

    public var refreshedFeedCount: Int {
        results.filter(\.isSuccess).count
    }

    public var failedFeedCount: Int {
        results.count - refreshedFeedCount
    }

    public var processedItemCount: Int {
        results.reduce(into: 0) { total, result in
            total += result.processedItemCount
        }
    }

    public var failures: [RSSFeedRefreshResult] {
        results.filter { $0.error != nil }
    }
}

public struct URLSessionRSSFeedDataLoader: RSSFeedDataLoading, Sendable {
    public init() {}

    public func loadData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return data
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw HTTPStatusError(statusCode: httpResponse.statusCode)
        }

        return data
    }
}

public struct FeedKitRSSFeedParser: RSSFeedParsing, Sendable {
    public init() {}

    public func parse(data: Data, sourceURL: URL) throws -> ParsedRSSDocument {
        let feed = try FeedKit.Feed(data: data)

        switch feed {
        case let .rss(rssFeed):
            return ParsedRSSDocument(
                feed: ParsedRSSFeed(
                    title: nonEmpty(rssFeed.channel?.title) ?? sourceURL.host ?? sourceURL.absoluteString,
                    feedURL: sourceURL,
                    category: rssFeed.channel?.categories?.compactMap(\.text).compactMap(nonEmpty).first
                ),
                items: rssFeed.channel?.items?.compactMap { parsedItem(from: $0) } ?? []
            )

        case let .atom(atomFeed):
            return ParsedRSSDocument(
                feed: ParsedRSSFeed(
                    title: nonEmpty(atomFeed.title?.text) ?? sourceURL.host ?? sourceURL.absoluteString,
                    feedURL: sourceURL,
                    category: atomFeed.categories?.compactMap { nonEmpty($0.attributes?.label) ?? nonEmpty($0.attributes?.term) }.first
                ),
                items: atomFeed.entries?.compactMap { parsedItem(from: $0) } ?? []
            )

        case let .json(jsonFeed):
            return ParsedRSSDocument(
                feed: ParsedRSSFeed(
                    title: nonEmpty(jsonFeed.title) ?? sourceURL.host ?? sourceURL.absoluteString,
                    feedURL: sourceURL,
                    category: nil
                ),
                items: jsonFeed.items?.compactMap { parsedItem(from: $0) } ?? []
            )
        }
    }

    private func parsedItem(from item: FeedKit.RSSFeedItem) -> ParsedRSSItem? {
        guard let linkURL = firstValidURL(from: [item.link, item.guid?.text]) else {
            return nil
        }

        let title = nonEmpty(item.title) ?? linkURL.absoluteString
        let content = nonEmpty(item.content?.encoded) ?? nonEmpty(item.description) ?? title

        return ParsedRSSItem(
            title: title,
            content: content,
            author: nonEmpty(item.author),
            publishedAt: item.pubDate,
            linkURL: linkURL
        )
    }

    private func parsedItem(from entry: AtomFeedEntry) -> ParsedRSSItem? {
        guard let linkURL = firstValidURL(
            from: preferredAtomLinkCandidates(entry.links) + [entry.id]
        ) else {
            return nil
        }

        let title = nonEmpty(entry.title) ?? linkURL.absoluteString
        let content = nonEmpty(entry.content?.text) ?? nonEmpty(entry.summary?.text) ?? title

        return ParsedRSSItem(
            title: title,
            content: content,
            author: entry.authors?.compactMap(\.name).compactMap(nonEmpty).first,
            publishedAt: entry.published ?? entry.updated,
            linkURL: linkURL
        )
    }

    private func parsedItem(from item: JSONFeedItem) -> ParsedRSSItem? {
        guard let linkURL = firstValidURL(from: [item.url, item.externalURL, item.id]) else {
            return nil
        }

        let title = nonEmpty(item.title) ?? linkURL.absoluteString
        let content = nonEmpty(item.contentText) ?? nonEmpty(item.contentHtml) ?? nonEmpty(item.summary) ?? title

        return ParsedRSSItem(
            title: title,
            content: content,
            author: nonEmpty(item.author?.name),
            publishedAt: item.datePublished ?? item.dateModified,
            linkURL: linkURL
        )
    }

    private func preferredAtomLinkCandidates(_ links: [AtomFeedLink]?) -> [String?] {
        let preferredLinks = links?
            .sorted { lhs, rhs in
                atomLinkPriority(lhs.attributes?.rel) < atomLinkPriority(rhs.attributes?.rel)
            }
            .map { $0.attributes?.href } ?? []

        return preferredLinks
    }

    private func atomLinkPriority(_ rel: String?) -> Int {
        switch rel?.lowercased() {
        case "alternate", nil:
            return 0
        case "self":
            return 1
        default:
            return 2
        }
    }
}

public struct RSSFetchService: RSSFetchServiceProtocol, Sendable {
    private let repository: RSSRepository
    private let dataLoader: RSSFeedDataLoading
    private let parser: RSSFeedParsing
    private let logger = Logger(subsystem: "me.lith", category: "RSSFetch")

    public init(
        repository: RSSRepository,
        dataLoader: RSSFeedDataLoading = URLSessionRSSFeedDataLoader(),
        parser: RSSFeedParsing = FeedKitRSSFeedParser()
    ) {
        self.repository = repository
        self.dataLoader = dataLoader
        self.parser = parser
    }

    public func refreshAllFeeds() async throws -> RSSRefreshReport {
        let startedAt = Date()
        let feeds = try await repository.feeds()
            .filter(\.isActive)

        var results: [RSSFeedRefreshResult] = []
        results.reserveCapacity(feeds.count)

        for feed in feeds {
            results.append(try await refresh(feed: feed))
        }

        return RSSRefreshReport(
            startedAt: startedAt,
            completedAt: Date(),
            results: results
        )
    }

    private func refresh(feed: RSSFeed) async throws -> RSSFeedRefreshResult {
        let refreshedAt = Date()

        do {
            let data = try await dataLoader.loadData(from: feed.feedURL)
            let parsedDocument = try parser.parse(data: data, sourceURL: feed.feedURL)
            let updatedFeed = mappedFeed(existingFeed: feed, parsedFeed: parsedDocument.feed)
            let items = parsedDocument.items.map { RSSItem(parsedItem: $0, feedID: feed.id) }

            try await repository.addFeed(updatedFeed)
            try await repository.upsertItems(items)
            try await repository.updateLastFetchedAt(for: feed.id, to: refreshedAt)

            return RSSFeedRefreshResult(
                feedID: feed.id,
                feedTitle: updatedFeed.title,
                feedURL: feed.feedURL,
                processedItemCount: items.count,
                refreshedAt: refreshedAt,
                error: nil
            )
        } catch let cancellationError as CancellationError {
            throw cancellationError
        } catch {
            let fetchError = mapError(error, for: feed.feedURL)
            log(fetchError, feedID: feed.id, feedTitle: feed.title)

            return RSSFeedRefreshResult(
                feedID: feed.id,
                feedTitle: feed.title,
                feedURL: feed.feedURL,
                processedItemCount: 0,
                refreshedAt: nil,
                error: fetchError
            )
        }
    }

    private func mappedFeed(existingFeed: RSSFeed, parsedFeed: ParsedRSSFeed) -> RSSFeed {
        RSSFeed(
            id: existingFeed.id,
            title: nonEmpty(parsedFeed.title) ?? existingFeed.title,
            feedURL: existingFeed.feedURL,
            category: nonEmpty(parsedFeed.category) ?? existingFeed.category,
            lastFetchedAt: existingFeed.lastFetchedAt,
            isActive: existingFeed.isActive,
            refreshIntervalSeconds: existingFeed.refreshIntervalSeconds
        )
    }

    private func mapError(_ error: Error, for feedURL: URL) -> RSSFetchError {
        if let fetchError = error as? RSSFetchError {
            return fetchError
        }

        if let statusError = error as? HTTPStatusError {
            return .network(
                feedURL: feedURL,
                reason: statusError.localizedDescription,
                retryable: statusError.statusCode >= 500
            )
        }

        if let urlError = error as? URLError {
            return .network(
                feedURL: feedURL,
                reason: urlError.localizedDescription,
                retryable: retryableNetworkCodes.contains(urlError.code)
            )
        }

        if error is FeedError || error is DecodingError {
            return .malformedFeed(feedURL: feedURL, reason: error.localizedDescription)
        }

        return .storage(feedURL: feedURL, reason: error.localizedDescription)
    }

    private func log(_ error: RSSFetchError, feedID: UUID, feedTitle: String) {
        logger.error(
            "RSS refresh failed for \(feedTitle, privacy: .public) [\(feedID.uuidString, privacy: .public)] at \(error.loggedURL, privacy: .public): \(error.localizedDescription, privacy: .public); retryable=\(error.isRetryable, privacy: .public)"
        )
    }
}

private struct HTTPStatusError: Error, LocalizedError, Sendable {
    let statusCode: Int

    var errorDescription: String? {
        "HTTP status \(statusCode)"
    }
}

private let retryableNetworkCodes: Set<URLError.Code> = [
    .timedOut,
    .cannotFindHost,
    .cannotConnectToHost,
    .networkConnectionLost,
    .dnsLookupFailed,
    .notConnectedToInternet,
    .resourceUnavailable,
]

private extension RSSFetchError {
    var loggedURL: String {
        switch self {
        case let .network(feedURL, _, _),
            let .malformedFeed(feedURL, _),
            let .storage(feedURL, _):
            return feedURL.absoluteString
        }
    }
}

private func firstValidURL(from candidates: [String?]) -> URL? {
    candidates
        .compactMap(nonEmpty)
        .lazy
        .compactMap(URL.init(string:))
        .first
}

private func nonEmpty(_ string: String?) -> String? {
    guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }

    return trimmed
}

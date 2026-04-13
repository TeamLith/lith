import Foundation
import Observation

@available(iOS 17, macOS 14, *)
@Observable
@MainActor
public final class RSSRefreshViewModel {
    public private(set) var feeds: [RSSFeed] = []
    public private(set) var isLoading = false
    public private(set) var isRefreshing = false
    public private(set) var loadError: Error?
    public private(set) var lastRefreshReport: RSSRefreshReport?

    private let repository: RSSRepository
    private let fetchService: RSSFetchServiceProtocol

    public init(repository: RSSRepository, fetchService: RSSFetchServiceProtocol) {
        self.repository = repository
        self.fetchService = fetchService
    }

    public func loadFeeds() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            feeds = try await repository.feeds()
        } catch {
            loadError = error
        }
    }

    public func refreshFeeds() async {
        isRefreshing = true
        loadError = nil
        defer { isRefreshing = false }

        do {
            lastRefreshReport = try await fetchService.refreshAllFeeds()
            feeds = try await repository.feeds()
        } catch {
            loadError = error
        }
    }
}

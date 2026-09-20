import Foundation
import Observation

public enum RSSInboxError: LocalizedError {
    case invalidURL, missingItem, missingFeed, approvalRequired, savedItem, missingSavedNote

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Enter a complete HTTP or HTTPS feed URL."
        case .missingItem: return "This article is no longer available. Refresh the inbox."
        case .missingFeed: return "The article's feed is no longer available."
        case .approvalRequired: return "Approve the article before saving it as a note."
        case .savedItem: return "This article is already saved as a note."
        case .missingSavedNote: return "The saved note is no longer available."
        }
    }
}

public struct RSSInboxGroup: Identifiable {
    public var id: UUID { feed.id }
    public let feed: RSSFeed
    public let items: [RSSItem]
    public var title: String {
        guard let category = feed.category, !category.isEmpty else { return feed.title }
        return "\(category) / \(feed.title)"
    }
}

@available(iOS 17, macOS 14, *)
@Observable
@MainActor
public final class RSSInboxViewModel {
    public private(set) var feeds: [RSSFeed] = []
    public private(set) var items: [RSSItem] = []
    public private(set) var isBusy = false
    public private(set) var error: Error?
    public private(set) var lastRefreshReport: RSSRefreshReport?
    public var statusFilter: RSSItemStatus? = .new

    private let repository: RSSRepository
    private let noteRepository: NoteRepository
    private let fetchService: RSSFetchServiceProtocol
    private let conversionService: RSSConversionServiceProtocol

    public init(repository: RSSRepository, noteRepository: NoteRepository,
                fetchService: RSSFetchServiceProtocol,
                conversionService: RSSConversionServiceProtocol = RSSConversionService()) {
        self.repository = repository
        self.noteRepository = noteRepository
        self.fetchService = fetchService
        self.conversionService = conversionService
    }

    public var groups: [RSSInboxGroup] {
        feeds.sorted {
            let left = ($0.category ?? "") + "/" + $0.title
            let right = ($1.category ?? "") + "/" + $1.title
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }.map { feed in
            RSSInboxGroup(feed: feed, items: items.filter {
                $0.feedID == feed.id && (statusFilter == nil || $0.status == statusFilter)
            })
        }
    }

    public func load() async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do { try await reload() } catch { self.error = error }
    }

    @discardableResult
    public func addFeed(url text: String, title: String, category: String) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            guard var components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme),
                  let host = components.host, !host.isEmpty,
                  components.user == nil, components.password == nil else { throw RSSInboxError.invalidURL }
            components.scheme = scheme
            components.host = host.lowercased()
            components.fragment = nil
            guard let url = components.url else { throw RSSInboxError.invalidURL }
            let existing = try await repository.feeds().first { $0.feedURL == url }
            if existing == nil {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
                try await repository.addFeed(RSSFeed(title: trimmedTitle.isEmpty ? host : trimmedTitle,
                    feedURL: url, category: trimmedCategory.isEmpty ? nil : trimmedCategory))
            }
            try await reload()
            return true
        } catch {
            self.error = error
            return false
        }
    }

    public func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            lastRefreshReport = try await fetchService.refreshAllFeeds()
            try await reload()
        } catch { self.error = error }
    }

    public func setStatus(_ status: RSSItemStatus, itemID: UUID) async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            guard let item = try await repository.item(id: itemID) else { throw RSSInboxError.missingItem }
            guard item.status != .savedAsNote else { throw RSSInboxError.savedItem }
            guard status != .savedAsNote else { throw RSSInboxError.approvalRequired }
            try await repository.updateItemWorkflow(itemID: itemID, status: status, savedNoteID: item.savedNoteID)
            try await reload()
        } catch { self.error = error }
    }

    /// A stable note identity makes retries safe even if the note was saved but the item update failed.
    @discardableResult
    public func saveAsNote(itemID: UUID, commentary: String = "") async -> UUID? {
        guard !isBusy else { return nil }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            guard let item = try await repository.item(id: itemID) else { throw RSSInboxError.missingItem }
            guard item.status == .approved || item.status == .savedAsNote else { throw RSSInboxError.approvalRequired }
            let noteID = item.savedNoteID ?? item.id
            if try await noteRepository.note(id: noteID) == nil {
                guard item.status == .approved else { throw RSSInboxError.missingSavedNote }
                guard let feed = try await repository.feed(id: item.feedID) else { throw RSSInboxError.missingFeed }
                let converted = conversionService.makeNote(from: item, feed: feed, commentary: commentary)
                var metadata = converted.metadata
                metadata["rssItemID"] = item.id.uuidString
                metadata["rssFeedID"] = item.feedID.uuidString
                let note = Note(id: noteID, title: converted.title, bodyMarkdown: converted.bodyMarkdown,
                                tags: converted.tags, source: .rss, metadata: metadata)
                try await noteRepository.upsert(note)
            }
            try await repository.updateItemWorkflow(itemID: item.id, status: .savedAsNote, savedNoteID: noteID)
            try await reload()
            return noteID
        } catch {
            self.error = error
            return nil
        }
    }

    private func reload() async throws {
        let feeds = try await repository.feeds()
        let items = try await repository.items(feedID: nil)
        self.feeds = feeds
        self.items = items
    }
}

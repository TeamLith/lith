import Foundation
import Observation

@Observable
@MainActor
public final class SearchViewModel {
    public var input = SearchInput()
    public private(set) var results: [Note] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var savedSearches: [SavedSearch] = []
    public private(set) var savedSearchError: String?
    public private(set) var isSavingSearch = false
    private let savedRepository: SavedSearchRepository?
    private let service: SearchServiceProtocol
    private var generation = 0

    public init(service: SearchServiceProtocol, savedRepository: SavedSearchRepository? = nil) {
        self.service = service
        self.savedRepository = savedRepository
    }

    public func search(calendar: Calendar = .current) async {
        generation += 1
        let requestGeneration = generation
        let request = input
        errorMessage = nil
        results = []
        isLoading = true
        defer {
            if generation == requestGeneration { isLoading = false }
        }

        do {
            let filters = try request.filters(calendar: calendar)
            let matches = try await service.search(
                query: request.query.trimmingCharacters(in: .whitespacesAndNewlines), filters: filters
            )
            guard generation == requestGeneration, input == request, !Task.isCancelled else { return }
            results = matches.filter { !$0.isArchived && !$0.isTrashed }.sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        } catch {
            guard generation == requestGeneration, input == request, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    public func loadSavedSearches() async {
        do {
            savedSearches = try await savedRepository?.all() ?? []
            savedSearchError = nil
        } catch { savedSearchError = error.localizedDescription }
    }

    @discardableResult
    public func saveSearch(name: String, calendar: Calendar = .current) async -> Bool {
        guard let savedRepository, !isSavingSearch else { return false }
        isSavingSearch = true
        defer { isSavingSearch = false }
        do {
            let saved = SavedSearch(name: name, query: input.query, filter: try input.filters(calendar: calendar), input: input)
            try await savedRepository.save(saved)
            await loadSavedSearches()
            return savedSearchError == nil
        } catch { savedSearchError = error.localizedDescription; return false }
    }

    public func applySavedSearch(_ saved: SavedSearch, calendar: Calendar = .current) async {
        if let snapshot = saved.input { input = snapshot }
        else {
            var restored = SearchInput()
            restored.query = saved.query
            restored.source = saved.filter.sources.count == 1 ? saved.filter.sources.first : nil
            restored.tags = saved.filter.tags.sorted().joined(separator: ", ")
            if let range = saved.filter.dateRange {
                restored.restrictDates = true
                restored.startDate = range.lowerBound
                restored.endDate = range.upperBound
            }
            input = restored
        }
        await search(calendar: calendar)
    }

    @discardableResult
    public func renameSavedSearch(id: UUID, name: String) async -> Bool {
        guard let savedRepository, !isSavingSearch else { return false }
        isSavingSearch = true
        defer { isSavingSearch = false }
        do {
            try await savedRepository.rename(id: id, name: name)
            await loadSavedSearches()
            return savedSearchError == nil
        } catch { savedSearchError = error.localizedDescription; return false }
    }

    public func deleteSavedSearch(id: UUID) async {
        guard let savedRepository, !isSavingSearch else { return }
        isSavingSearch = true
        defer { isSavingSearch = false }
        do { try await savedRepository.delete(id: id); await loadSavedSearches() }
        catch { savedSearchError = error.localizedDescription }
    }

    public func clearFilters() {
        input = SearchInput()
    }

    public func snippet(for note: Note) -> String {
        let text = note.bodyMarkdown.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let query = input.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = query.isEmpty ? nil : text.range(of: query, options: .caseInsensitive)
        let start = match.map { text.index($0.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex } ?? text.startIndex
        let end = text.index(start, offsetBy: 180, limitedBy: text.endIndex) ?? text.endIndex
        return (start == text.startIndex ? "" : "…") + String(text[start..<end]) + (end == text.endIndex ? "" : "…")
    }
}

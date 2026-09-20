import Foundation
import Testing
@testable import Lith

@MainActor
@Suite("SearchViewModel")
struct SearchViewModelTests {
    @Test("Query and combined source, tag, and inclusive day filters reach the search service")
    func filters() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 86_400)
        let match = Note(title: "Swift", bodyMarkdown: "Search text", tags: ["work"], updatedAt: day.addingTimeInterval(86_399), source: .rss)
        let wrongSource = Note(title: "Swift", bodyMarkdown: "", tags: ["work"], updatedAt: day, source: .manual)
        let wrongDay = Note(title: "Swift", bodyMarkdown: "", tags: ["work"], updatedAt: day.addingTimeInterval(86_400), source: .rss)
        let wrongTag = Note(title: "Swift", bodyMarkdown: "", tags: ["home"], updatedAt: day, source: .rss)
        let wrongQuery = Note(title: "Cooking", bodyMarkdown: "", tags: ["work"], updatedAt: day, source: .rss)
        let vm = SearchViewModel(service: SearchService(repository: InMemoryNoteRepository(seed: [match, wrongSource, wrongDay, wrongTag, wrongQuery])))
        vm.input.query = " Swift "
        vm.input.source = .rss
        vm.input.tags = " WORK, , personal "
        vm.input.restrictDates = true
        vm.input.startDate = day
        vm.input.endDate = day
        await vm.search(calendar: calendar)
        #expect(vm.results.map(\.id) == [match.id])
        #expect(!vm.isLoading)
        #expect(vm.errorMessage == nil)
        vm.clearFilters()
        await vm.search()
        #expect(vm.results.count == 5)
    }

    @Test("Empty query sorts active notes deterministically and excludes archive and trash")
    func sortingAndVisibility() async {
        let date = Date(timeIntervalSince1970: 100)
        let first = Note(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "First", bodyMarkdown: "", updatedAt: date)
        let second = Note(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, title: "Second", bodyMarkdown: "", updatedAt: date)
        let newest = Note(title: "New", bodyMarkdown: "", updatedAt: date.addingTimeInterval(1))
        let archived = Note(title: "Archive", bodyMarkdown: "", isArchived: true)
        let trashed = Note(title: "Trash", bodyMarkdown: "", isTrashed: true)
        let vm = SearchViewModel(service: SearchService(repository: InMemoryNoteRepository(seed: [second, archived, first, newest, trashed])))
        await vm.search()
        #expect(vm.results.map(\.id) == [newest.id, first.id, second.id])
    }

    @Test("Invalid ranges produce a recoverable validation error")
    func invalidDates() async {
        let vm = SearchViewModel(service: SearchService(repository: InMemoryNoteRepository()))
        vm.input.restrictDates = true
        vm.input.startDate = Date(timeIntervalSince1970: 172_800)
        vm.input.endDate = Date(timeIntervalSince1970: 0)
        await vm.search()
        #expect(vm.errorMessage != nil)
        #expect(!vm.isLoading)
        vm.clearFilters()
        await vm.search()
        #expect(vm.errorMessage == nil)
    }

    @Test("Late responses cannot overwrite newer search results")
    func overlappingSearches() async {
        let service = ControlledSearchService()
        let vm = SearchViewModel(service: service)
        vm.input.query = "old"
        let old = Task { await vm.search() }
        await service.waitForRequest("old")
        vm.input.query = "new"
        let new = Task { await vm.search() }
        await service.waitForRequest("new")
        let expected = Note(title: "New result", bodyMarkdown: "")
        await service.finish("new", result: .success([expected]))
        await new.value
        await service.finish("old", result: .success([Note(title: "Stale", bodyMarkdown: "")]))
        await old.value
        #expect(vm.results.map(\.id) == [expected.id])
        #expect(!vm.isLoading)
    }

    @Test("Failure clears stale results and retry recovers")
    func retry() async {
        let service = ControlledSearchService()
        let vm = SearchViewModel(service: service)
        let failure = Task { await vm.search() }
        await service.waitForRequest("")
        await service.finish("", result: .failure(SearchTestError.failed))
        await failure.value
        #expect(vm.errorMessage != nil)
        #expect(vm.results.isEmpty)
        let retry = Task { await vm.search() }
        await service.waitForRequest("")
        await service.finish("", result: .success([Note(title: "Recovered", bodyMarkdown: "")]))
        await retry.value
        #expect(vm.errorMessage == nil)
        #expect(vm.results.count == 1)
    }

    @Test("Snippets include matches beyond the start of a long body")
    func snippets() {
        let vm = SearchViewModel(service: SearchService(repository: InMemoryNoteRepository()))
        vm.input.query = "needle"
        let note = Note(title: "Long", bodyMarkdown: String(repeating: "intro ", count: 100) + "needle " + String(repeating: "end ", count: 100))
        #expect(vm.snippet(for: note).contains("needle"))
        #expect(vm.snippet(for: note).count <= 182)
    }
}

private enum SearchTestError: Error { case failed }

private actor ControlledSearchService: SearchServiceProtocol {
    private var pending: [String: CheckedContinuation<[Note], Error>] = [:]
    private var waiting: [String: CheckedContinuation<Void, Never>] = [:]

    func search(query: String, filters: SearchFilter) async throws -> [Note] {
        try await withCheckedThrowingContinuation { continuation in
            pending[query] = continuation
            waiting.removeValue(forKey: query)?.resume()
        }
    }

    func waitForRequest(_ query: String) async {
        if pending[query] != nil { return }
        await withCheckedContinuation { waiting[query] = $0 }
    }

    func finish(_ query: String, result: Result<[Note], Error>) {
        pending.removeValue(forKey: query)?.resume(with: result)
    }
}

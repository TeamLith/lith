import Foundation
import Testing
@testable import Lith

@Suite("Saved searches")
struct SavedSearchTests {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("searches.json")
    }

    @Test("Save, rename, and delete survive fresh repository instances without altering filters")
    func persistence() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var input = SearchInput()
        input.query = "Swift AND CloudKit"
        input.source = .rss
        input.tags = "work, swift"
        input.restrictDates = true
        input.startDate = Date(timeIntervalSince1970: 1_000)
        input.endDate = Date(timeIntervalSince1970: 100_000)
        let saved = SavedSearch(name: " Research ", query: input.query, filter: try input.filters(), input: input)
        try await LocalSavedSearchRepository(url: url).save(saved)
        let reopened = LocalSavedSearchRepository(url: url)
        let loaded = try #require(await reopened.all().first)
        #expect(loaded.id == saved.id && loaded.name == "Research")
        #expect(loaded.input == input && loaded.filter == saved.filter)
        try await reopened.rename(id: saved.id, name: "Reading")
        let renamed = try #require(await LocalSavedSearchRepository(url: url).all().first)
        #expect(renamed.name == "Reading" && renamed.input == input)
        try await reopened.delete(id: saved.id)
        #expect(try await LocalSavedSearchRepository(url: url).all().isEmpty)
    }

    @Test("Invalid and duplicate names fail without overwriting existing searches")
    func names() async throws {
        let repository = LocalSavedSearchRepository(url: nil)
        let saved = SavedSearch(name: "Work", query: "one", filter: SearchFilter())
        try await repository.save(saved)
        for name in [" ", "Bad\nName", String(repeating: "x", count: 81), "work"] {
            await #expect(throws: SavedSearchError.self) {
                try await repository.save(SavedSearch(name: name, query: "two", filter: SearchFilter()))
            }
        }
        await #expect(throws: SavedSearchError.self) { try await repository.rename(id: saved.id, name: "") }
        #expect(try await repository.all() == [saved])
    }

    @Test("Corrupt stores are reported and preserved on attempted writes")
    func corruptStore() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("not valid JSON".utf8)
        try original.write(to: url)
        let repository = LocalSavedSearchRepository(url: url)
        await #expect(throws: SavedSearchError.self) { try await repository.all() }
        await #expect(throws: SavedSearchError.self) {
            try await repository.save(SavedSearch(name: "New", query: "", filter: SearchFilter()))
        }
        #expect(try Data(contentsOf: url) == original)
    }

    @MainActor
    @Test("Selecting a saved search restores all controls and immediately finds matching notes")
    func restoration() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let matching = Note(title: "Swift", bodyMarkdown: "", tags: ["work"], updatedAt: date, source: .rss)
        let other = Note(title: "Swift", bodyMarkdown: "", tags: ["home"], updatedAt: date, source: .manual)
        let notes = InMemoryNoteRepository(seed: [matching, other])
        let repository = LocalSavedSearchRepository(url: nil)
        let vm = SearchViewModel(service: SearchService(repository: notes), savedRepository: repository)
        vm.input.query = " Swift "
        vm.input.source = .rss
        vm.input.tags = " WORK, personal "
        vm.input.restrictDates = true
        vm.input.startDate = date
        vm.input.endDate = date
        let original = vm.input
        #expect(await vm.saveSearch(name: "Articles"))
        let saved = try #require(vm.savedSearches.first)
        vm.clearFilters()
        await vm.applySavedSearch(saved)
        #expect(vm.input == original)
        #expect(vm.results.map(\.id) == [matching.id])
        #expect(await vm.renameSavedSearch(id: saved.id, name: "Reading"))
        await vm.deleteSavedSearch(id: saved.id)
        #expect(vm.savedSearches.isEmpty)
        #expect(try await notes.allNotes().count == 2)
    }

    @MainActor
    @Test("Inactive date values survive saving and invalid active ranges are rejected")
    func dateState() async throws {
        let vm = SearchViewModel(service: SearchService(repository: InMemoryNoteRepository()), savedRepository: LocalSavedSearchRepository(url: nil))
        vm.input.startDate = Date(timeIntervalSince1970: 200_000)
        vm.input.endDate = Date(timeIntervalSince1970: 0)
        let original = vm.input
        #expect(await vm.saveSearch(name: "No date filter"))
        let saved = try #require(vm.savedSearches.first)
        vm.clearFilters()
        await vm.applySavedSearch(saved)
        #expect(vm.input == original)
        vm.input.restrictDates = true
        #expect(!(await vm.saveSearch(name: "Invalid")))
        #expect(vm.savedSearchError != nil)
        #expect(vm.savedSearches.count == 1)
    }
}

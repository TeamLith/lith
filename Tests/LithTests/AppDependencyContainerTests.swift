#if canImport(CoreData)
import CoreData
import Foundation
import Testing
@testable import Lith

@available(macOS 10.15, iOS 13.0, *)
@Test func appDependencyContainerBootstrapsInMemoryStore() throws {
    let dependencies = try AppDependencyContainer(mode: .inMemory)
    let stores = dependencies.persistentContainer.persistentStoreCoordinator.persistentStores

    #expect(stores.count == 1)
    #expect(stores.first?.type == NSInMemoryStoreType)
}

@available(macOS 10.15, iOS 13.0, *)
@Test func appDependencyContainerWiresRepositoriesAndSearch() async throws {
    let dependencies = try AppDependencyContainer(mode: .inMemory)
    let note = Note(title: "Container smoke", bodyMarkdown: "Searchable body")

    try await dependencies.noteRepository.upsert(note)

    let fetched = try await dependencies.noteRepository.note(id: note.id)
    let searchResults = try await dependencies.searchService.search(
        query: "Searchable",
        filters: SearchFilter()
    )
    let refreshReport = try await dependencies.rssFetchService.refreshAllFeeds()

    #expect(fetched?.id == note.id)
    #expect(searchResults.map(\.id).contains(note.id))
    #expect(refreshReport.results.isEmpty)
}

@available(macOS 10.15, iOS 13.0, *)
@Test func appDependencyContainerWiresWikiLinkPersistence() async throws {
    let dependencies = try AppDependencyContainer(mode: .inMemory)
    let target = Note(title: "Target", bodyMarkdown: "")
    let source = Note(title: "Source", bodyMarkdown: "See [[Target]]")

    try await dependencies.noteRepository.upsert(target)
    try await dependencies.noteRepository.upsert(source)
    _ = try await dependencies.wikiLinkService.refreshLinks(for: source.id)

    let backlinks = try await dependencies.wikiLinkService.backlinks(to: target.id)

    #expect(backlinks.map(\.id) == [source.id])
    #expect(try await dependencies.linkRepository.backlinks(to: target.id).count == 1)
}
#endif

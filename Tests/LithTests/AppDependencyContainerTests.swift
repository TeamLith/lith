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

    #expect(fetched?.id == note.id)
    #expect(searchResults.map(\.id).contains(note.id))
}
#endif

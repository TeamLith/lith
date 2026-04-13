#if canImport(CoreData)
import Foundation
import Testing
@testable import Lith

@available(macOS 10.15, iOS 13.0, *)
@Test("replaceLinks persists wikilinks and preserves identity across refreshes")
func replaceLinksPersistsAndPreservesIdentity() async throws {
    let container = try LithPersistentStore.makeContainer(inMemory: true)
    let repository = CoreDataLinkRepository(container: container)
    let sourceID = UUID()
    let targetID = UUID()

    try await repository.replaceLinks(
        from: sourceID,
        with: [Link(fromNoteID: sourceID, toNoteID: targetID, type: .wikilink)]
    )

    let firstStored = try await repository.links(from: sourceID)
    try await repository.replaceLinks(
        from: sourceID,
        with: [Link(fromNoteID: sourceID, toNoteID: targetID, type: .wikilink)]
    )

    let secondStored = try await repository.links(from: sourceID)

    #expect(firstStored.count == 1)
    #expect(secondStored.count == 1)
    #expect(firstStored.first?.id == secondStored.first?.id)
    #expect(firstStored.first?.createdAt == secondStored.first?.createdAt)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("replaceLinks removes stale wikilinks when a note changes")
func replaceLinksRemovesStaleLinks() async throws {
    let container = try LithPersistentStore.makeContainer(inMemory: true)
    let repository = CoreDataLinkRepository(container: container)
    let sourceID = UUID()
    let firstTargetID = UUID()
    let secondTargetID = UUID()

    try await repository.replaceLinks(
        from: sourceID,
        with: [Link(fromNoteID: sourceID, toNoteID: firstTargetID, type: .wikilink)]
    )
    try await repository.replaceLinks(
        from: sourceID,
        with: [Link(fromNoteID: sourceID, toNoteID: secondTargetID, type: .wikilink)]
    )

    let outgoing = try await repository.links(from: sourceID)
    let firstBacklinks = try await repository.backlinks(to: firstTargetID)
    let secondBacklinks = try await repository.backlinks(to: secondTargetID)

    #expect(outgoing.map(\.toNoteID) == [secondTargetID])
    #expect(firstBacklinks.isEmpty)
    #expect(secondBacklinks.map(\.fromNoteID) == [sourceID])
}
#endif

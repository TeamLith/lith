#if canImport(CoreData)
import CoreData
import Foundation
import Testing
@testable import Lith

@available(macOS 10.15, iOS 13.0, *)
@Test func coreDataNoteRepositoryCreatesAndFetchesNotes() async throws {
    let repository = CoreDataNoteRepository(container: try LithPersistentStore.makeContainer(inMemory: true))
    let note = Note(
        id: UUID(),
        title: "Design notes",
        bodyMarkdown: "Body",
        tags: ["swift", "coredata"],
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: Date(timeIntervalSince1970: 200),
        accessedAt: Date(timeIntervalSince1970: 300),
        source: .manual,
        isPinned: true,
        isArchived: false,
        isTrashed: false,
        metadata: ["origin": "test"]
    )

    try await repository.upsert(note)

    let fetched = try await repository.note(id: note.id)
    #expect(fetched == note)
}

@available(macOS 10.15, iOS 13.0, *)
@Test func coreDataNoteRepositoryUpdatesExistingNotesByIdentifier() async throws {
    let repository = CoreDataNoteRepository(container: try LithPersistentStore.makeContainer(inMemory: true))
    let id = UUID()
    let original = Note(
        id: id,
        title: "Weekly plan",
        bodyMarkdown: "v1",
        updatedAt: Date(timeIntervalSince1970: 10),
        isArchived: false
    )
    let updated = Note(
        id: id,
        title: "Weekly plan revised",
        bodyMarkdown: "v2",
        tags: ["planning"],
        createdAt: original.createdAt,
        updatedAt: Date(timeIntervalSince1970: 20),
        accessedAt: Date(timeIntervalSince1970: 30),
        source: .manual,
        isPinned: true,
        isArchived: true,
        isTrashed: false,
        metadata: ["editor": "codex"]
    )

    try await repository.upsert(original)
    try await repository.upsert(updated)

    let fetched = try await repository.note(id: id)
    let allNotes = try await repository.allNotes()

    #expect(fetched == updated)
    #expect(allNotes.count == 1)
}

@available(macOS 10.15, iOS 13.0, *)
@Test func coreDataNoteRepositoryDeletesNotes() async throws {
    let repository = CoreDataNoteRepository(container: try LithPersistentStore.makeContainer(inMemory: true))
    let note = Note(title: "Temporary", bodyMarkdown: "Delete me")

    try await repository.upsert(note)
    try await repository.delete(noteID: note.id)

    let fetched = try await repository.note(id: note.id)
    let allNotes = try await repository.allNotes()

    #expect(fetched == nil)
    #expect(allNotes.isEmpty)
}

@available(macOS 10.15, iOS 13.0, *)
@Test func coreDataNoteRepositoryReturnsNewestNotesFirst() async throws {
    let repository = CoreDataNoteRepository(container: try LithPersistentStore.makeContainer(inMemory: true))
    let older = Note(title: "Older", bodyMarkdown: "", updatedAt: Date(timeIntervalSince1970: 10))
    let newer = Note(title: "Newer", bodyMarkdown: "", updatedAt: Date(timeIntervalSince1970: 20))

    try await repository.upsert(older)
    try await repository.upsert(newer)

    let notes = try await repository.allNotes()
    #expect(notes.map(\.id) == [newer.id, older.id])
}
#endif

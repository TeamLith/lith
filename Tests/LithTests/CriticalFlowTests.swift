import Foundation
import Testing
@testable import Lith
#if canImport(CoreData)
import CoreData

@MainActor
struct CriticalFlowTests {
    @Test func noteCRUDWikilinksAndSearchShareDurableState() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let list = NoteListViewModel(repository: dependencies.noteRepository)
        let destination = Note(title: "Roadmap", bodyMarkdown: "Planning reference")
        try await dependencies.noteRepository.upsert(destination)
        let created = try #require(await list.createNote())
        let detail = NoteDetailViewModel(noteID: created.id, repository: dependencies.noteRepository, wikiLinkService: dependencies.wikiLinkService)
        await detail.loadNote()
        detail.title = "Weekly meeting"
        detail.bodyMarkdown = "Discuss [[Roadmap]] and deployment"
        _ = try #require(await detail.saveNow())
        let search = SearchViewModel(service: dependencies.searchService)
        search.input.query = "deployment"
        await search.search()
        #expect(search.results.map(\.id) == [created.id])
        #expect(try await dependencies.wikiLinkService.backlinks(to: destination.id).map(\.id) == [created.id])
        _ = await detail.archive()
        await search.search()
        #expect(search.results.isEmpty)
        await list.moveToTrash(noteID: created.id)
        await list.delete(noteID: created.id)
        #expect(try await dependencies.noteRepository.note(id: created.id) == nil)
        #expect(try await dependencies.noteRepository.note(id: destination.id) != nil)
    }

    @Test func approvedRSSArticleAppearsOnceInSearchWithSourceMetadata() async throws {
        let dependencies = try AppDependencyContainer(mode: .inMemory)
        let feed = RSSFeed(title: "Engineering", feedURL: URL(string: "https://example.com/feed")!)
        let article = RSSItem(feedID: feed.id, title: "Reliable systems", content: "Durable storage matters", linkURL: URL(string: "https://example.com/article")!)
        try await dependencies.rssRepository.addFeed(feed)
        try await dependencies.rssRepository.upsertItems([article])
        let inbox = RSSInboxViewModel(repository: dependencies.rssRepository, noteRepository: dependencies.noteRepository,
                                      fetchService: dependencies.rssFetchService, wikiLinkService: dependencies.wikiLinkService)
        await inbox.load()
        #expect(await inbox.saveAsNote(itemID: article.id) == nil)
        #expect(try await dependencies.noteRepository.allNotes().isEmpty)
        await inbox.setStatus(.approved, itemID: article.id)
        let noteID = try #require(await inbox.saveAsNote(itemID: article.id, commentary: "Read before planning"))
        #expect(await inbox.saveAsNote(itemID: article.id) == noteID)
        let reloadedRSS = CoreDataRSSRepository(container: dependencies.persistentContainer)
        #expect(try await reloadedRSS.item(id: article.id)?.savedNoteID == noteID)
        let search = SearchViewModel(service: dependencies.searchService)
        search.input.query = "Reliable"
        search.input.source = .rss
        await search.search()
        let result = try #require(search.results.first)
        #expect(search.results.count == 1)
        #expect(result.id == noteID)
        #expect(result.metadata["rssItemID"] == article.id.uuidString)
        #expect(result.bodyMarkdown.contains("Read before planning"))
    }

    @Test func legacySQLiteUpgradeRetainsNotesFeedsItemsAndLinks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Lith.sqlite")
        let currentModel = try LithPersistentStore.makeContainer(inMemory: true).managedObjectModel
        let legacyModel = currentModel.copy() as! NSManagedObjectModel
        legacyModel.entities = legacyModel.entities.filter { ["Note", "RSSFeed", "RSSItem", "Link"].contains($0.name ?? "") }
        // Runtime class names do not change the stored schema. Generic fixture objects
        // avoid registering a second model for the production managed subclasses.
        for entity in legacyModel.entities {
            let storedSchemaHash = entity.versionHash
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
            #expect(entity.versionHash == storedSchemaHash)
        }
        let legacy = NSPersistentContainer(name: "Lith", managedObjectModel: legacyModel)
        let description = NSPersistentStoreDescription(url: url)
        description.shouldAddStoreAsynchronously = false
        legacy.persistentStoreDescriptions = [description]
        var loadError: Error?
        legacy.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        let note = Note(title: "Legacy library", bodyMarkdown: "Must survive upgrade", tags: ["important"])
        let target = Note(title: "Legacy target", bodyMarkdown: "Linked")
        let feed = RSSFeed(title: "Legacy feed", feedURL: URL(string: "https://example.com/legacy")!)
        let item = RSSItem(feedID: feed.id, title: "Legacy article", content: "Keep me", linkURL: URL(string: "https://example.com/legacy-item")!, status: .approved)
        let link = Link(fromNoteID: note.id, toNoteID: target.id, type: .wikilink)
        try await legacy.performBackgroundTask { @Sendable context in
            for value in [note, target] {
                let object = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context)
                object.setValuesForKeys([
                    "id": value.id, "title": value.title, "bodyMarkdown": value.bodyMarkdown,
                    "createdAt": value.createdAt, "updatedAt": value.updatedAt, "sourceRawValue": value.source.rawValue,
                    "isPinned": value.isPinned, "isArchived": value.isArchived, "isTrashed": value.isTrashed,
                    "tagsData": try JSONEncoder().encode(value.tags), "metadataData": try JSONEncoder().encode(value.metadata)
                ])
            }
            let managedFeed = NSEntityDescription.insertNewObject(forEntityName: "RSSFeed", into: context)
            managedFeed.setValuesForKeys(["id": feed.id, "title": feed.title, "urlString": feed.feedURL.absoluteString,
                                         "isActive": feed.isActive, "refreshIntervalSeconds": feed.refreshIntervalSeconds])
            let managedItem = NSEntityDescription.insertNewObject(forEntityName: "RSSItem", into: context)
            managedItem.setValuesForKeys(["id": item.id, "feedID": feed.id, "title": item.title, "content": item.content,
                                         "linkURLString": item.linkURL.absoluteString, "statusRawValue": item.status.rawValue,
                                         "feed": managedFeed])
            let managedLink = NSEntityDescription.insertNewObject(forEntityName: "Link", into: context)
            managedLink.setValuesForKeys(["id": link.id, "fromNoteID": link.fromNoteID, "toNoteID": link.toNoteID,
                                         "typeRawValue": link.type.rawValue, "createdAt": link.createdAt])
            try context.save()
        }
        for store in legacy.persistentStoreCoordinator.persistentStores { try legacy.persistentStoreCoordinator.remove(store) }

        let upgraded = try LithPersistentStore.makeContainer(storeURL: url)
        let notes = CoreDataNoteRepository(container: upgraded)
        let rss = CoreDataRSSRepository(container: upgraded)
        #expect(try await notes.note(id: note.id) == note)
        #expect(try await notes.note(id: target.id) == target)
        #expect(try await rss.feed(id: feed.id) == feed)
        #expect(try await rss.item(id: item.id) == item)
        #expect(try await CoreDataLinkRepository(container: upgraded).links().map(\.id) == [link.id])
        let audio = CoreDataAudioRecordingRepository(container: upgraded)
        let recording = AudioRecording(noteID: note.id, fileURL: directory.appendingPathComponent("recording.m4a"))
        try await audio.upsert(recording)
        #expect(try await audio.recording(id: recording.id)?.noteID == note.id)
        for store in upgraded.persistentStoreCoordinator.persistentStores { try upgraded.persistentStoreCoordinator.remove(store) }
    }
}
#endif

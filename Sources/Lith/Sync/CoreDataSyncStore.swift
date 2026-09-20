#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

/// Fresh contexts avoid cached snapshots; error merge policy rejects writes racing a local editor.
public final class CoreDataSyncStore: SyncLocalStore, @unchecked Sendable {
    private let container: NSPersistentContainer
    private let audioCleanup: SyncAudioDeletionJournal?
    public init(container: NSPersistentContainer, audioFiles: AudioFileStore? = nil) {
        self.container = container
        // In-memory previews/tests must never inspect the user's real audio directory.
        let files = audioFiles ?? (container.persistentStoreCoordinator.persistentStores.contains {
            $0.type != NSInMemoryStoreType
        } ? AudioFileStore() : nil)
        self.audioCleanup = files.map(SyncAudioDeletionJournal.init)
    }

    public func snapshot() async throws -> [CloudRecord] {
        let context = container.newBackgroundContext()
        return try await context.perform {
            try LithStoreWriteLock.withLock {
                try self.audioCleanup?.recover(in: context)
                var result: [CloudRecord] = []
                let feeds = try Self.feedIdentities(context)
                let items = try Self.itemIdentities(context, feeds: feeds)
                for (kind, entity) in Self.entities where context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[entity] != nil {
                    let request = NSFetchRequest<NSManagedObject>(entityName: entity)
                    for object in try context.fetch(request) { result.append(try Self.encode(object, kind: kind, feeds: feeds, items: items)) }
                }
                var unique: [String: CloudRecord] = [:]
                for record in result {
                    if let previous = unique[record.id], !syncContentEqual(previous, record) {
                        throw SyncEngineError.configuration("Duplicate local RSS identities have different content. Resolve the duplicate feeds before syncing.")
                    }
                    unique[record.id] = record
                }
                return Array(unique.values)
            }
        }
    }

    public func apply(_ record: CloudRecord, ifUnchanged expected: CloudRecord?) async throws {
        try record.validate()
        if !record.deleted {
            let naturalID: UUID
            switch record.kind {
            case .feed: naturalID = SyncIdentity.feed(try record.decode(RSSFeed.self).feedURL)
            case .item:
                let item = try record.decode(RSSItem.self)
                naturalID = SyncIdentity.item(feedID: item.feedID, url: item.linkURL)
            case .link:
                let link = try record.decode(Link.self)
                naturalID = SyncIdentity.link(from: link.fromNoteID, to: link.toNoteID, type: link.type)
            default: naturalID = record.entityID
            }
            guard naturalID == record.entityID else { throw CloudRecordError.invalidRecord }
        }
        let context = container.newBackgroundContext()
        context.mergePolicy = NSErrorMergePolicy
        try await context.perform {
            try LithStoreWriteLock.withLock {
                do {
                    try self.audioCleanup?.recover(in: context)
                    guard let entity = Self.entities[record.kind],
                          context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[entity] != nil else {
                        throw SyncEngineError.unsupportedEntity(record.kind.rawValue)
                    }
                    let feeds = try Self.feedIdentities(context)
                    let items = try Self.itemIdentities(context, feeds: feeds)
                    let request = NSFetchRequest<NSManagedObject>(entityName: entity)
                    // Canonical natural identity avoids different-device UUID collisions with local uniqueness rules.
                    let existing = try context.fetch(request).first {
                        try Self.encode($0, kind: record.kind, feeds: feeds, items: items).id == record.id
                    }
                    let current = try existing.map { try Self.encode($0, kind: record.kind, feeds: feeds, items: items) }
                    guard syncContentEqual(current, expected) else { throw SyncEngineError.localChanged }
                    if record.deleted {
                        if let feed = existing as? ManagedRSSFeed, !feed.items.isEmpty {
                            // Never allow Core Data's feed cascade to erase unreviewed child changes.
                            throw SyncEngineError.dependentRecords
                        }
                        if record.kind == .note, existing != nil,
                           try Self.hasNoteDependents(record.entityID, in: context) {
                            throw SyncEngineError.dependentRecords
                        }
                        if record.kind == .audio, let current {
                            let recording = try current.decode(AudioRecording.self)
                            guard recording.recordingState != .recording, recording.status != .processing else {
                                throw SyncEngineError.dependentRecords
                            }
                            try self.audioCleanup?.prepare(recording)
                        }
                        if let existing { context.delete(existing) }
                    } else {
                        try Self.requireParents(for: record, in: context)
                        let object = existing ?? NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
                        try Self.apply(record, to: object, context: context)
                    }
                    if context.hasChanges { try context.save() }
                    // A durable intent was written before the metadata commit. If file
                    // removal fails or the process exits, the next snapshot retries it.
                    try self.audioCleanup?.recover(in: context)
                } catch {
                    context.rollback()
                    throw error
                }
            }
        }
    }

    private static let entities: [CloudRecord.Kind: String] = [
        .note: "Note", .link: "Link", .feed: "RSSFeed", .item: "RSSItem",
        .audio: "AudioRecording", .action: "ActionItem"
    ]
    private static func hasNoteDependents(_ id: UUID, in context: NSManagedObjectContext) throws -> Bool {
        for (entity, predicate) in [
            ("AudioRecording", NSPredicate(format: "noteID == %@", id as CVarArg)),
            ("ActionItem", NSPredicate(format: "sourceNoteID == %@", id as CVarArg)),
            ("Link", NSPredicate(format: "fromNoteID == %@ OR toNoteID == %@", id as CVarArg, id as CVarArg))
        ] where context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[entity] != nil {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = predicate
            request.fetchLimit = 1
            if try context.count(for: request) > 0 { return true }
        }
        return false
    }

    private static func requireParents(for record: CloudRecord, in context: NSManagedObjectContext) throws {
        let parentIDs: [UUID]
        switch record.kind {
        case .audio: parentIDs = [try record.decode(AudioRecording.self).noteID]
        case .action: parentIDs = [try record.decode(ActionItem.self).sourceNoteID]
        case .link:
            let link = try record.decode(Link.self)
            parentIDs = [link.fromNoteID, link.toNoteID]
        default: return
        }
        for id in parentIDs {
            let request = ManagedNote.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard try context.count(for: request) > 0 else {
                throw SyncEngineError.configuration("A synced attachment or link is waiting for its note. Sync again.")
            }
        }
    }
    private static func feedIdentities(_ context: NSManagedObjectContext) throws -> [UUID: UUID] {
        try Dictionary(uniqueKeysWithValues: context.fetch(ManagedRSSFeed.fetchRequest()).map {
            let feed = try $0.toDomainFeed()
            return (feed.id, SyncIdentity.feed(feed.feedURL))
        })
    }
    private static func itemIdentities(_ context: NSManagedObjectContext, feeds: [UUID: UUID]) throws -> [UUID: UUID] {
        try Dictionary(uniqueKeysWithValues: context.fetch(ManagedRSSItem.fetchRequest()).map {
            let item = try $0.toDomainItem()
            guard let feed = feeds[item.feedID] else { throw CloudRecordError.invalidRecord }
            return (item.id, SyncIdentity.item(feedID: feed, url: item.linkURL))
        })
    }
    private static func rewrite<T: Encodable>(_ value: T, kind: CloudRecord.Kind, id: UUID,
                                               fields: [String: Any] = [:], date: Date) throws -> CloudRecord {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String: Any]
        object["id"] = id.uuidString
        for (key, value) in fields { object[key] = value }
        return try CloudRecord(kind: kind, entityID: id, modifiedAt: date,
                               payload: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    }
    private static func encode(_ object: NSManagedObject, kind: CloudRecord.Kind, feeds: [UUID: UUID], items: [UUID: UUID]) throws -> CloudRecord {
        switch kind {
        case .note:
            var note = try (object as! ManagedNote).toDomainNote()
            if let text = note.metadata["rssFeedID"], let id = UUID(uuidString: text), let canonical = feeds[id] {
                note.metadata["rssFeedID"] = canonical.uuidString
            }
            if let text = note.metadata["rssItemID"], let id = UUID(uuidString: text), let canonical = items[id] {
                note.metadata["rssItemID"] = canonical.uuidString
            }
            return try .encode(note, kind: kind, id: note.id, modifiedAt: note.updatedAt)
        case .link:
            let link = try (object as! ManagedLink).toDomainLink()
            return try rewrite(link, kind: kind, id: SyncIdentity.link(from: link.fromNoteID, to: link.toNoteID, type: link.type), date: link.createdAt)
        case .feed:
            let feed = try (object as! ManagedRSSFeed).toDomainFeed()
            // Refresh time is device-local operational state, not an edit to feed configuration.
            return try rewrite(feed, kind: kind, id: SyncIdentity.feed(feed.feedURL),
                               fields: ["lastFetchedAt": NSNull()], date: .distantPast)
        case .item:
            let item = try (object as! ManagedRSSItem).toDomainItem()
            guard let feedID = feeds[item.feedID] else { throw CloudRecordError.invalidRecord }
            return try rewrite(item, kind: kind, id: SyncIdentity.item(feedID: feedID, url: item.linkURL),
                               fields: ["feedID": feedID.uuidString], date: .distantPast)
        case .audio, .action:
            guard let id = object.value(forKey: "id") as? UUID,
                  let data = object.value(forKey: "payload") as? Data else { throw CloudRecordError.invalidRecord }
            let json = try JSONSerialization.jsonObject(with: data)
            let canonical = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            let date = (json as? [String: Any])?["updatedAt"] as? Double
            return try CloudRecord(kind: kind, entityID: id,
                                   modifiedAt: date.map(Date.init(timeIntervalSinceReferenceDate:)) ?? .distantPast,
                                   payload: canonical)
        case .tag: throw SyncEngineError.unsupportedEntity(kind.rawValue)
        }
    }
    private static func apply(_ record: CloudRecord, to object: NSManagedObject, context: NSManagedObjectContext) throws {
        switch record.kind {
        case .note:
            var note = try record.decode(Note.self)
            let feeds = try feedIdentities(context)
            let items = try itemIdentities(context, feeds: feeds)
            if let text = note.metadata["rssFeedID"], let id = UUID(uuidString: text), let local = feeds.first(where: { $0.value == id })?.key {
                note.metadata["rssFeedID"] = local.uuidString
            }
            if let text = note.metadata["rssItemID"], let id = UUID(uuidString: text), let local = items.first(where: { $0.value == id })?.key {
                note.metadata["rssItemID"] = local.uuidString
            }
            try (object as! ManagedNote).apply(note)
        case .link:
            let value = try record.decode(Link.self)
            let localID = object.isInserted ? value.id : (object as! ManagedLink).id
            try (object as! ManagedLink).apply(value, id: localID, createdAt: value.createdAt)
        case .feed:
            var value = try record.decode(RSSFeed.self)
            if !object.isInserted {
                let local = object as! ManagedRSSFeed
                value = RSSFeed(id: local.id, title: value.title, feedURL: value.feedURL, category: value.category,
                                lastFetchedAt: local.lastFetchedAt, isActive: value.isActive,
                                refreshIntervalSeconds: value.refreshIntervalSeconds)
            }
            (object as! ManagedRSSFeed).apply(value)
        case .item:
            let value = try record.decode(RSSItem.self)
            let request = ManagedRSSFeed.fetchRequest()
            guard let feed = try context.fetch(request).first(where: {
                SyncIdentity.feed(try $0.toDomainFeed().feedURL) == value.feedID
            }) else {
                throw SyncEngineError.configuration("An RSS article is waiting for its feed. Sync again.")
            }
            let localID = object.isInserted ? value.id : (object as! ManagedRSSItem).id
            let localValue = RSSItem(id: localID, feedID: feed.id, title: value.title, content: value.content,
                                    author: value.author, publishedAt: value.publishedAt, linkURL: value.linkURL,
                                    status: value.status, savedNoteID: value.savedNoteID)
            try (object as! ManagedRSSItem).apply(localValue, feed: feed)
        case .audio, .action:
            // These entities keep their portable Codable model in payload. Detect them dynamically so
            // the sync engine can precede their additive schema migrations.
            let json = try JSONSerialization.jsonObject(with: record.payload) as? [String: Any]
            let parentKey = record.kind == .audio ? "noteID" : "sourceNoteID"
            guard let text = json?[parentKey] as? String, let parent = UUID(uuidString: text) else {
                throw CloudRecordError.invalidRecord
            }
            object.setValue(record.entityID, forKey: "id")
            object.setValue(record.payload, forKey: "payload")
            if object.entity.attributesByName["noteID"] != nil { object.setValue(parent, forKey: "noteID") }
            if object.entity.attributesByName["sourceNoteID"] != nil { object.setValue(parent, forKey: "sourceNoteID") }
            if object.entity.attributesByName["recordedAt"] != nil {
                let seconds = json?["recordedAt"] as? Double
                object.setValue(seconds.map(Date.init(timeIntervalSinceReferenceDate:)) ?? record.modifiedAt, forKey: "recordedAt")
            }
        case .tag: throw SyncEngineError.unsupportedEntity(record.kind.rawValue)
        }
    }
}
#endif

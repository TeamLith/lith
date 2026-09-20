#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

/// Fresh contexts avoid cached snapshots; error merge policy rejects writes racing a local editor.
public final class CoreDataSyncStore: SyncLocalStore, @unchecked Sendable {
    private let container: NSPersistentContainer
    public init(container: NSPersistentContainer) { self.container = container }

    public func snapshot() async throws -> [CloudRecord] {
        let context = container.newBackgroundContext()
        return try await context.perform {
            var result: [CloudRecord] = []
            for (kind, entity) in Self.entities where context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[entity] != nil {
                let request = NSFetchRequest<NSManagedObject>(entityName: entity)
                for object in try context.fetch(request) { result.append(try Self.encode(object, kind: kind)) }
            }
            return result
        }
    }

    public func apply(_ record: CloudRecord, ifUnchanged expected: CloudRecord?) async throws {
        try record.validate()
        let context = container.newBackgroundContext()
        context.mergePolicy = NSErrorMergePolicy
        try await context.perform {
            do {
                guard let entity = Self.entities[record.kind],
                      context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[entity] != nil else {
                    throw SyncEngineError.unsupportedEntity(record.kind.rawValue)
                }
                let request = NSFetchRequest<NSManagedObject>(entityName: entity)
                request.predicate = NSPredicate(format: "id == %@", record.entityID as CVarArg)
                let existing = try context.fetch(request).first
                let current = try existing.map { try Self.encode($0, kind: record.kind) }
                guard syncContentEqual(current, expected) else { throw SyncEngineError.localChanged }
                if record.deleted {
                    if let existing { context.delete(existing) }
                } else {
                    let object = existing ?? NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
                    try Self.apply(record, to: object, context: context)
                }
                if context.hasChanges { try context.save() }
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    private static let entities: [CloudRecord.Kind: String] = [
        .note: "Note", .link: "Link", .feed: "RSSFeed", .item: "RSSItem",
        .audio: "AudioRecording", .action: "ActionItem"
    ]
    private static func encode(_ object: NSManagedObject, kind: CloudRecord.Kind) throws -> CloudRecord {
        switch kind {
        case .note:
            let note = try (object as! ManagedNote).toDomainNote()
            return try .encode(note, kind: kind, id: note.id, modifiedAt: note.updatedAt)
        case .link:
            let link = try (object as! ManagedLink).toDomainLink()
            return try .encode(link, kind: kind, id: link.id, modifiedAt: link.createdAt)
        case .feed:
            let feed = try (object as! ManagedRSSFeed).toDomainFeed()
            return try .encode(feed, kind: kind, id: feed.id, modifiedAt: .distantPast)
        case .item:
            let item = try (object as! ManagedRSSItem).toDomainItem()
            return try .encode(item, kind: kind, id: item.id, modifiedAt: .distantPast)
        case .audio, .action:
            guard let id = object.value(forKey: "id") as? UUID,
                  let data = object.value(forKey: "payload") as? Data else { throw CloudRecordError.invalidRecord }
            let json = try JSONSerialization.jsonObject(with: data)
            let canonical = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            return try CloudRecord(kind: kind, entityID: id, modifiedAt: .distantPast, payload: canonical)
        case .tag: throw SyncEngineError.unsupportedEntity(kind.rawValue)
        }
    }
    private static func apply(_ record: CloudRecord, to object: NSManagedObject, context: NSManagedObjectContext) throws {
        switch record.kind {
        case .note: try (object as! ManagedNote).apply(record.decode(Note.self))
        case .link:
            let value = try record.decode(Link.self)
            try (object as! ManagedLink).apply(value, id: value.id, createdAt: value.createdAt)
        case .feed: (object as! ManagedRSSFeed).apply(try record.decode(RSSFeed.self))
        case .item:
            let value = try record.decode(RSSItem.self)
            let request = ManagedRSSFeed.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", value.feedID as CVarArg)
            guard let feed = try context.fetch(request).first else {
                throw SyncEngineError.configuration("An RSS article is waiting for its feed. Sync again.")
            }
            try (object as! ManagedRSSItem).apply(value, feed: feed)
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

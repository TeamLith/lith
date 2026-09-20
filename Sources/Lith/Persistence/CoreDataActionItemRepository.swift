#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

public final class CoreDataActionItemRepository: @unchecked Sendable, ActionItemRepository {
    private let context: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .errorMergePolicyType)
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil
    }

    public func upsert(_ item: ActionItem) async throws {
        let data = try JSONEncoder().encode(item)
        try await perform {
            try self.requireParent(item.sourceNoteID)
            let record = try self.fetch(item.id) ?? NSEntityDescription.insertNewObject(forEntityName: "ActionItem", into: self.context)
            record.setValue(item.id, forKey: "id")
            record.setValue(item.sourceNoteID, forKey: "sourceNoteID")
            record.setValue(data, forKey: "payload")
            record.setValue(item.createdAt, forKey: "createdAt")
            record.setValue(item.updatedAt, forKey: "updatedAt")
            try self.context.save()
        }
    }

    public func updateExisting(_ item: ActionItem, expected: ActionItem) async throws {
        let data = try JSONEncoder().encode(item)
        try await perform {
            try self.requireParent(item.sourceNoteID)
            guard let record = try self.fetch(item.id) else { throw ActionItemReviewError.missingNote }
            guard try self.decode(record) == expected else { throw NoteWriteError.conflict }
            record.setValue(data, forKey: "payload")
            record.setValue(item.createdAt, forKey: "createdAt")
            record.setValue(item.updatedAt, forKey: "updatedAt")
            try self.context.save()
        }
    }

    private func requireParent(_ id: UUID) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.predicate = NSPredicate(format: "id == %@ AND isTrashed == NO", id as CVarArg)
        request.fetchLimit = 1
        guard try !context.fetch(request).isEmpty else { throw ActionItemReviewError.missingNote }
    }

    public func items(noteID: UUID?) async throws -> [ActionItem] {
        try await perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ActionItem")
            if let noteID { request.predicate = NSPredicate(format: "sourceNoteID == %@", noteID as CVarArg) }
            return try self.context.fetch(request).map(self.decode).sorted {
                if $0.createdAt != $1.createdAt { return ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
                return $0.id.uuidString < $1.id.uuidString
            }
        }
    }

    public func item(id: UUID) async throws -> ActionItem? {
        try await perform { try self.fetch(id).map(self.decode) }
    }

    public func delete(itemID: UUID) async throws {
        try await perform {
            if let record = try self.fetch(itemID) {
                self.context.delete(record)
                try self.context.save()
            }
        }
    }

    private func fetch(_ id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionItem")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func decode(_ record: NSManagedObject) throws -> ActionItem {
        guard let data = record.value(forKey: "payload") as? Data else { throw ActionItemPersistenceError.invalidRecord }
        let item = try JSONDecoder().decode(ActionItem.self, from: data)
        guard item.id == record.value(forKey: "id") as? UUID,
              item.sourceNoteID == record.value(forKey: "sourceNoteID") as? UUID else { throw ActionItemPersistenceError.invalidRecord }
        return item
    }

    private func perform<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await context.perform {
            try LithStoreWriteLock.withLock {
                self.context.reset()
                do { return try work() }
                catch { self.context.rollback(); throw error }
            }
        }
    }
}

private enum ActionItemPersistenceError: Error { case invalidRecord }

extension LithPersistentStore {
    static func makeActionItemEntities() -> [NSEntityDescription] {
        let entity = NSEntityDescription()
        entity.name = "ActionItem"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = [
            actionAttribute("id", .UUIDAttributeType),
            actionAttribute("sourceNoteID", .UUIDAttributeType),
            actionAttribute("payload", .binaryDataAttributeType),
            actionAttribute("createdAt", .dateAttributeType, optional: true),
            actionAttribute("updatedAt", .dateAttributeType, optional: true)
        ]
        entity.uniquenessConstraints = [["id"]]
        return [entity]
    }

    private static func actionAttribute(_ name: String, _ type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
        let field = NSAttributeDescription()
        field.name = name
        field.attributeType = type
        field.isOptional = optional
        return field
    }
}
#endif

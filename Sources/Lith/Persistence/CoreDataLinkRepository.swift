#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

@available(macOS 10.15, iOS 13.0, *)
public final class CoreDataLinkRepository: @unchecked Sendable, LinkRepository {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    public init() throws {
        self.container = try LithPersistentStore.makeContainer()
        self.context = container.newBackgroundContext()
        self.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        self.context.undoManager = nil
    }

    public init(container: NSPersistentContainer) {
        self.container = container
        self.context = container.newBackgroundContext()
        self.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        self.context.undoManager = nil
    }

    public func replaceLinks(from sourceNoteID: UUID, with links: [Link]) async throws {
        try await perform {
            let existingLinks = try self.fetchManagedLinks(from: sourceNoteID)
            let existingByKey = Dictionary(
                uniqueKeysWithValues: existingLinks.map { (ManagedLinkIdentity(link: $0), $0) }
            )

            let deduplicatedLinks = links.reduce(into: [ManagedLinkIdentity: Link]()) { result, link in
                let identity = ManagedLinkIdentity(link: link)
                if result[identity] == nil {
                    result[identity] = link
                }
            }

            for managedLink in existingLinks where !deduplicatedLinks.keys.contains(ManagedLinkIdentity(link: managedLink)) {
                self.context.delete(managedLink)
            }

            for (identity, link) in deduplicatedLinks {
                let managedLink = existingByKey[identity] ?? ManagedLink(context: self.context)
                let preservedID = existingByKey[identity]?.id ?? link.id
                let preservedCreatedAt = existingByKey[identity]?.createdAt ?? link.createdAt
                try managedLink.apply(link, id: preservedID, createdAt: preservedCreatedAt)
            }

            try self.saveIfNeeded()
        }
    }

    public func links() async throws -> [Link] {
        try await perform {
            let request = ManagedLink.fetchRequest()
            request.sortDescriptors = self.sortDescriptors
            return try self.context.fetch(request).map { try $0.toDomainLink() }
        }
    }

    public func links(from sourceNoteID: UUID) async throws -> [Link] {
        try await perform {
            let request = ManagedLink.fetchRequest()
            request.sortDescriptors = self.sortDescriptors
            request.predicate = NSPredicate(format: "%K == %@", #keyPath(ManagedLink.fromNoteID), sourceNoteID as CVarArg)
            return try self.context.fetch(request).map { try $0.toDomainLink() }
        }
    }

    public func backlinks(to targetNoteID: UUID) async throws -> [Link] {
        try await perform {
            let request = ManagedLink.fetchRequest()
            request.sortDescriptors = self.sortDescriptors
            request.predicate = NSPredicate(format: "%K == %@", #keyPath(ManagedLink.toNoteID), targetNoteID as CVarArg)
            return try self.context.fetch(request).map { try $0.toDomainLink() }
        }
    }

    private var sortDescriptors: [NSSortDescriptor] {
        [
            NSSortDescriptor(key: #keyPath(ManagedLink.createdAt), ascending: true),
            NSSortDescriptor(key: #keyPath(ManagedLink.fromNoteID), ascending: true),
            NSSortDescriptor(key: #keyPath(ManagedLink.toNoteID), ascending: true)
        ]
    }

    private func fetchManagedLinks(from sourceNoteID: UUID) throws -> [ManagedLink] {
        let request = ManagedLink.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(ManagedLink.fromNoteID), sourceNoteID as CVarArg)
        return try context.fetch(request)
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    private func perform<T>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum CoreDataLinkRepositoryError: Error {
    case invalidType(String)
}

@objc(ManagedLink)
final class ManagedLink: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var fromNoteID: UUID
    @NSManaged var toNoteID: UUID
    @NSManaged var typeRawValue: String
    @NSManaged var createdAt: Date
}

extension ManagedLink {
    @nonobjc static func fetchRequest() -> NSFetchRequest<ManagedLink> {
        NSFetchRequest<ManagedLink>(entityName: "Link")
    }

    func apply(_ link: Link, id: UUID, createdAt: Date) throws {
        self.id = id
        fromNoteID = link.fromNoteID
        toNoteID = link.toNoteID
        typeRawValue = link.type.rawValue
        self.createdAt = createdAt
    }

    func toDomainLink() throws -> Link {
        guard let type = LinkType(rawValue: typeRawValue) else {
            throw CoreDataLinkRepositoryError.invalidType(typeRawValue)
        }

        return Link(
            id: id,
            fromNoteID: fromNoteID,
            toNoteID: toNoteID,
            type: type,
            createdAt: createdAt
        )
    }
}

extension LithPersistentStore {
    static func makeLinkEntities() -> [NSEntityDescription] {
        let entity = NSEntityDescription()
        entity.name = "Link"
        entity.managedObjectClassName = NSStringFromClass(ManagedLink.self)
        entity.properties = [
            attribute(name: "id", type: .UUIDAttributeType, optional: false),
            attribute(name: "fromNoteID", type: .UUIDAttributeType, optional: false),
            attribute(name: "toNoteID", type: .UUIDAttributeType, optional: false),
            attribute(name: "typeRawValue", type: .stringAttributeType, optional: false),
            attribute(name: "createdAt", type: .dateAttributeType, optional: false)
        ]
        entity.uniquenessConstraints = [["id"], ["fromNoteID", "toNoteID", "typeRawValue"]]
        return [entity]
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        optional: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}

private struct ManagedLinkIdentity: Hashable {
    let fromNoteID: UUID
    let toNoteID: UUID
    let typeRawValue: String

    init(link: Link) {
        self.fromNoteID = link.fromNoteID
        self.toNoteID = link.toNoteID
        self.typeRawValue = link.type.rawValue
    }

    init(link: ManagedLink) {
        self.fromNoteID = link.fromNoteID
        self.toNoteID = link.toNoteID
        self.typeRawValue = link.typeRawValue
    }
}
#endif

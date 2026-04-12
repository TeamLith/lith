#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

@available(macOS 10.15, iOS 13.0, *)
public final class CoreDataRSSRepository: @unchecked Sendable, RSSRepository {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    public init() throws {
        self.container = try NativeNotesPersistentStore.makeContainer()
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

    public func addFeed(_ feed: RSSFeed) async throws {
        try await perform {
            if let managedFeed = try self.fetchManagedFeed(id: feed.id)
                ?? self.fetchManagedFeed(urlString: feed.feedURL.absoluteString) {
                let domainFeed = self.merge(existing: managedFeed.toDomainFeedOrNil(), incoming: feed)
                managedFeed.apply(domainFeed)
            } else {
                let managedFeed = ManagedRSSFeed(context: self.context)
                managedFeed.apply(feed)
            }
            try self.saveIfNeeded()
        }
    }

    public func feeds() async throws -> [RSSFeed] {
        try await perform {
            let request = ManagedRSSFeed.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(ManagedRSSFeed.title), ascending: true)]
            return try self.context.fetch(request).map { try $0.toDomainFeed() }
        }
    }

    public func feed(id: UUID) async throws -> RSSFeed? {
        try await perform {
            try self.fetchManagedFeed(id: id)?.toDomainFeed()
        }
    }

    public func updateLastFetchedAt(for feedID: UUID, to date: Date?) async throws {
        try await perform {
            guard let managedFeed = try self.fetchManagedFeed(id: feedID) else {
                return
            }
            managedFeed.lastFetchedAt = date
            try self.saveIfNeeded()
        }
    }

    public func upsertItems(_ items: [RSSItem]) async throws {
        try await perform {
            for item in items {
                guard let managedFeed = try self.fetchManagedFeed(id: item.feedID) else {
                    throw CoreDataRSSRepositoryError.missingFeed(item.feedID)
                }

                let existingManagedItem = try self.fetchManagedItem(id: item.id)
                    ?? self.fetchManagedItem(feedID: item.feedID, linkURLString: item.linkURL.absoluteString)
                let managedItem: ManagedRSSItem
                let domainItem: RSSItem

                if let existingManagedItem {
                    managedItem = existingManagedItem
                    domainItem = try self.merge(existing: existingManagedItem.toDomainItemOrNil(), incoming: item)
                } else {
                    managedItem = ManagedRSSItem(context: self.context)
                    domainItem = self.merge(existing: nil, incoming: item)
                }

                try managedItem.apply(domainItem, feed: managedFeed)
            }
            try self.saveIfNeeded()
        }
    }

    public func items(feedID: UUID? = nil) async throws -> [RSSItem] {
        try await perform {
            let request = ManagedRSSItem.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: #keyPath(ManagedRSSItem.publishedAt), ascending: false),
                NSSortDescriptor(key: #keyPath(ManagedRSSItem.title), ascending: true)
            ]
            if let feedID {
                request.predicate = NSPredicate(format: "%K == %@", #keyPath(ManagedRSSItem.feedID), feedID as CVarArg)
            }
            return try self.context.fetch(request).map { try $0.toDomainItem() }
        }
    }

    public func item(id: UUID) async throws -> RSSItem? {
        try await perform {
            try self.fetchManagedItem(id: id)?.toDomainItem()
        }
    }

    private func fetchManagedFeed(id: UUID) throws -> ManagedRSSFeed? {
        let request = ManagedRSSFeed.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(ManagedRSSFeed.id), id as CVarArg)
        return try context.fetch(request).first
    }

    private func fetchManagedFeed(urlString: String) throws -> ManagedRSSFeed? {
        let request = ManagedRSSFeed.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(ManagedRSSFeed.urlString), urlString)
        return try context.fetch(request).first
    }

    private func fetchManagedItem(id: UUID) throws -> ManagedRSSItem? {
        let request = ManagedRSSItem.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(ManagedRSSItem.id), id as CVarArg)
        return try context.fetch(request).first
    }

    private func fetchManagedItem(feedID: UUID, linkURLString: String) throws -> ManagedRSSItem? {
        let request = ManagedRSSItem.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %@", #keyPath(ManagedRSSItem.feedID), feedID as CVarArg),
            NSPredicate(format: "%K == %@", #keyPath(ManagedRSSItem.linkURLString), linkURLString)
        ])
        return try context.fetch(request).first
    }

    private func merge(existing: RSSFeed?, incoming: RSSFeed) -> RSSFeed {
        guard let existing else {
            return incoming
        }
        return mergedFeed(existing: existing, incoming: incoming)
    }

    private func merge(existing: RSSItem?, incoming: RSSItem) -> RSSItem {
        guard let existing else {
            return incoming
        }
        return mergedItem(existing: existing, incoming: incoming)
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

enum CoreDataRSSRepositoryError: Error {
    case missingFeed(UUID)
    case invalidURL(String)
    case invalidStatus(String)
}

@objc(ManagedRSSFeed)
final class ManagedRSSFeed: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var urlString: String
    @NSManaged var category: String?
    @NSManaged var lastFetchedAt: Date?
    @NSManaged var isActive: Bool
    @NSManaged var refreshIntervalSeconds: Int32
    @NSManaged var items: Set<ManagedRSSItem>
}

extension ManagedRSSFeed {
    @nonobjc static func fetchRequest() -> NSFetchRequest<ManagedRSSFeed> {
        NSFetchRequest<ManagedRSSFeed>(entityName: "RSSFeed")
    }

    func apply(_ feed: RSSFeed) {
        id = feed.id
        title = feed.title
        urlString = feed.feedURL.absoluteString
        category = feed.category
        lastFetchedAt = feed.lastFetchedAt
        isActive = feed.isActive
        refreshIntervalSeconds = feed.refreshIntervalSeconds
    }

    func toDomainFeed() throws -> RSSFeed {
        guard let url = URL(string: urlString) else {
            throw CoreDataRSSRepositoryError.invalidURL(urlString)
        }
        return RSSFeed(
            id: id,
            title: title,
            feedURL: url,
            category: category,
            lastFetchedAt: lastFetchedAt,
            isActive: isActive,
            refreshIntervalSeconds: refreshIntervalSeconds
        )
    }

    func toDomainFeedOrNil() -> RSSFeed? {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            return nil
        }
        return RSSFeed(
            id: id,
            title: title,
            feedURL: url,
            category: category,
            lastFetchedAt: lastFetchedAt,
            isActive: isActive,
            refreshIntervalSeconds: refreshIntervalSeconds
        )
    }
}

@objc(ManagedRSSItem)
final class ManagedRSSItem: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var feedID: UUID
    @NSManaged var title: String
    @NSManaged var content: String
    @NSManaged var author: String?
    @NSManaged var linkURLString: String
    @NSManaged var publishedAt: Date?
    @NSManaged var statusRawValue: String
    @NSManaged var savedNoteID: UUID?
    @NSManaged var feed: ManagedRSSFeed
}

extension ManagedRSSItem {
    @nonobjc static func fetchRequest() -> NSFetchRequest<ManagedRSSItem> {
        NSFetchRequest<ManagedRSSItem>(entityName: "RSSItem")
    }

    func apply(_ item: RSSItem, feed: ManagedRSSFeed) throws {
        id = item.id
        feedID = item.feedID
        title = item.title
        content = item.content
        author = item.author
        linkURLString = item.linkURL.absoluteString
        publishedAt = item.publishedAt
        statusRawValue = item.status.rawValue
        savedNoteID = item.savedNoteID
        self.feed = feed
    }

    func toDomainItem() throws -> RSSItem {
        guard let linkURL = URL(string: linkURLString) else {
            throw CoreDataRSSRepositoryError.invalidURL(linkURLString)
        }
        guard let status = RSSItemStatus(rawValue: statusRawValue) else {
            throw CoreDataRSSRepositoryError.invalidStatus(statusRawValue)
        }

        return RSSItem(
            id: id,
            feedID: feedID,
            title: title,
            content: content,
            author: author,
            publishedAt: publishedAt,
            linkURL: linkURL,
            status: status,
            savedNoteID: savedNoteID
        )
    }

    func toDomainItemOrNil() throws -> RSSItem? {
        guard !linkURLString.isEmpty else {
            return nil
        }
        return try toDomainItem()
    }
}

extension NativeNotesPersistentStore {
    static func makeRSSEntities() -> [NSEntityDescription] {
        let feedEntity = NSEntityDescription()
        feedEntity.name = "RSSFeed"
        feedEntity.managedObjectClassName = NSStringFromClass(ManagedRSSFeed.self)

        let itemEntity = NSEntityDescription()
        itemEntity.name = "RSSItem"
        itemEntity.managedObjectClassName = NSStringFromClass(ManagedRSSItem.self)

        let feedToItems = relationship(
            name: "items",
            destinationEntity: itemEntity,
            minCount: 0,
            maxCount: 0,
            deleteRule: .cascadeDeleteRule,
            isOptional: true
        )
        let itemToFeed = relationship(
            name: "feed",
            destinationEntity: feedEntity,
            minCount: 1,
            maxCount: 1,
            deleteRule: .nullifyDeleteRule,
            isOptional: false
        )
        feedToItems.inverseRelationship = itemToFeed
        itemToFeed.inverseRelationship = feedToItems

        feedEntity.properties = [
            attribute(name: "id", type: .UUIDAttributeType, optional: false),
            attribute(name: "title", type: .stringAttributeType, optional: false),
            attribute(name: "urlString", type: .stringAttributeType, optional: false),
            attribute(name: "category", type: .stringAttributeType, optional: true),
            attribute(name: "lastFetchedAt", type: .dateAttributeType, optional: true),
            attribute(name: "isActive", type: .booleanAttributeType, optional: false),
            attribute(name: "refreshIntervalSeconds", type: .integer32AttributeType, optional: false),
            feedToItems
        ]
        feedEntity.uniquenessConstraints = [["id"], ["urlString"]]

        itemEntity.properties = [
            attribute(name: "id", type: .UUIDAttributeType, optional: false),
            attribute(name: "feedID", type: .UUIDAttributeType, optional: false),
            attribute(name: "title", type: .stringAttributeType, optional: false),
            attribute(name: "content", type: .stringAttributeType, optional: false),
            attribute(name: "author", type: .stringAttributeType, optional: true),
            attribute(name: "linkURLString", type: .stringAttributeType, optional: false),
            attribute(name: "publishedAt", type: .dateAttributeType, optional: true),
            attribute(name: "statusRawValue", type: .stringAttributeType, optional: false),
            attribute(name: "savedNoteID", type: .UUIDAttributeType, optional: true),
            itemToFeed
        ]
        itemEntity.uniquenessConstraints = [["id"], ["feedID", "linkURLString"]]

        return [feedEntity, itemEntity]
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

    private static func relationship(
        name: String,
        destinationEntity: NSEntityDescription,
        minCount: Int,
        maxCount: Int,
        deleteRule: NSDeleteRule,
        isOptional: Bool
    ) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destinationEntity
        relationship.minCount = minCount
        relationship.maxCount = maxCount
        relationship.deleteRule = deleteRule
        relationship.isOptional = isOptional
        relationship.isOrdered = false
        return relationship
    }
}
#endif

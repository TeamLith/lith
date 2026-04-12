#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

public final class CoreDataNoteRepository: @unchecked Sendable, NoteRepository {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    public init() {
        self.container = NativeNotesPersistentStore.makeContainer()
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

    public func upsert(_ note: Note) async throws {
        try context.performSync {
            let managedNote = try self.fetchManagedNote(id: note.id) ?? ManagedNote(context: self.context)
            managedNote.apply(note)
            try self.saveIfNeeded()
        }
    }

    public func delete(noteID: UUID) async throws {
        try context.performSync {
            guard let managedNote = try self.fetchManagedNote(id: noteID) else {
                return
            }
            self.context.delete(managedNote)
            try self.saveIfNeeded()
        }
    }

    public func allNotes() async throws -> [Note] {
        try context.performSync {
            let request = ManagedNote.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(ManagedNote.updatedAt), ascending: false)]
            return try self.context.fetch(request).map { try $0.toDomainNote() }
        }
    }

    public func note(id: UUID) async throws -> Note? {
        try context.performSync {
            try self.fetchManagedNote(id: id)?.toDomainNote()
        }
    }

    private func fetchManagedNote(id: UUID) throws -> ManagedNote? {
        let request = ManagedNote.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(ManagedNote.id), id as CVarArg)
        return try context.fetch(request).first
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}

enum NativeNotesPersistentStore {
    static func makeContainer(inMemory: Bool = false) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "NativeNotes", managedObjectModel: managedObjectModel())
        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
        } else {
            description.type = NSSQLiteStoreType
            description.url = defaultStoreURL()
        }
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            precondition(error == nil, "Failed to load NativeNotes persistent store: \(String(describing: error))")
        }
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.undoManager = nil
        return container
    }

    private static func defaultStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("NativeNotes.sqlite")
    }

    private static func managedObjectModel() -> NSManagedObjectModel {
        ModelCache.model
    }

    fileprivate static func makeNoteEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "Note"
        entity.managedObjectClassName = NSStringFromClass(ManagedNote.self)
        entity.properties = [
            attribute(name: "id", type: .UUIDAttributeType, optional: false),
            attribute(name: "title", type: .stringAttributeType, optional: false),
            attribute(name: "bodyMarkdown", type: .stringAttributeType, optional: false),
            attribute(name: "createdAt", type: .dateAttributeType, optional: false),
            attribute(name: "updatedAt", type: .dateAttributeType, optional: false),
            attribute(name: "accessedAt", type: .dateAttributeType, optional: true),
            attribute(name: "sourceRawValue", type: .stringAttributeType, optional: false),
            attribute(name: "isPinned", type: .booleanAttributeType, optional: false),
            attribute(name: "isArchived", type: .booleanAttributeType, optional: false),
            attribute(name: "isTrashed", type: .booleanAttributeType, optional: false),
            attribute(name: "tagsData", type: .binaryDataAttributeType, optional: false),
            attribute(name: "metadataData", type: .binaryDataAttributeType, optional: false)
        ]
        entity.uniquenessConstraints = [["id"]]
        return entity
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

@objc(ManagedNote)
final class ManagedNote: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var bodyMarkdown: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var accessedAt: Date?
    @NSManaged var sourceRawValue: String
    @NSManaged var isPinned: Bool
    @NSManaged var isArchived: Bool
    @NSManaged var isTrashed: Bool
    @NSManaged var tagsData: Data
    @NSManaged var metadataData: Data
}

extension ManagedNote {
    @nonobjc static func fetchRequest() -> NSFetchRequest<ManagedNote> {
        NSFetchRequest<ManagedNote>(entityName: "Note")
    }

    func apply(_ note: Note) {
        id = note.id
        title = note.title
        bodyMarkdown = note.bodyMarkdown
        createdAt = note.createdAt
        updatedAt = note.updatedAt
        accessedAt = note.accessedAt
        sourceRawValue = note.source.rawValue
        isPinned = note.isPinned
        isArchived = note.isArchived
        isTrashed = note.isTrashed
        tagsData = encode(note.tags)
        metadataData = encode(note.metadata)
    }

    func toDomainNote() throws -> Note {
        guard let source = NoteSource(rawValue: sourceRawValue) else {
            throw CoreDataNoteRepositoryError.invalidSource(sourceRawValue)
        }

        return Note(
            id: id,
            title: title,
            bodyMarkdown: bodyMarkdown,
            tags: try decode(tagsData, as: Set<String>.self),
            createdAt: createdAt,
            updatedAt: updatedAt,
            accessedAt: accessedAt,
            source: source,
            isPinned: isPinned,
            isArchived: isArchived,
            isTrashed: isTrashed,
            metadata: try decode(metadataData, as: [String: String].self)
        )
    }

    private func encode<T: Encodable>(_ value: T) -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            preconditionFailure("Failed to encode managed note payload: \(error)")
        }
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

enum CoreDataNoteRepositoryError: Error {
    case invalidSource(String)
}

extension NSManagedObjectContext {
    fileprivate func performSync<T: Sendable>(_ work: @escaping @Sendable () throws -> T) throws -> T {
        let box = ManagedContextResultBox<T>()
        performAndWait {
            box.result = Result { try work() }
        }
        return try box.result.get()
    }
}

private final class ManagedContextResultBox<T: Sendable>: @unchecked Sendable {
    var result: Result<T, Error>!
}

private enum ModelCache {
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        model.entities = [NativeNotesPersistentStore.makeNoteEntity()]
        return model
    }()
}
#endif

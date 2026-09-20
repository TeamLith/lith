#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

public final class CoreDataAudioRecordingRepository: @unchecked Sendable, AudioRecordingRepository {
    private let context: NSManagedObjectContext
    private let files: AudioFileStore
    public init(container: NSPersistentContainer, files: AudioFileStore = AudioFileStore()) {
        context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        self.files = files
    }
    public func upsert(_ recording: AudioRecording) async throws {
        try await context.perform {
            let object = try self.fetch(id: recording.id) ?? NSManagedObject(entity: self.context.persistentStoreCoordinator!.managedObjectModel.entitiesByName["AudioRecording"]!, insertInto: self.context)
            object.setValue(recording.id, forKey: "id")
            object.setValue(recording.noteID, forKey: "noteID")
            object.setValue(recording.recordedAt, forKey: "recordedAt")
            object.setValue(try JSONEncoder().encode(recording), forKey: "payload")
            try self.context.save()
        }
    }
    public func recordings(noteID: UUID? = nil) async throws -> [AudioRecording] {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "AudioRecording")
            if let noteID { request.predicate = NSPredicate(format: "noteID == %@", noteID as CVarArg) }
            request.sortDescriptors = [NSSortDescriptor(key: "recordedAt", ascending: false)]
            return try self.context.fetch(request).map(self.decode)
        }
    }
    public func recording(id: UUID) async throws -> AudioRecording? {
        try await context.perform { try self.fetch(id: id).map(self.decode) }
    }
    public func delete(recordingID: UUID) async throws {
        try await context.perform {
            if let object = try self.fetch(id: recordingID) {
                self.context.delete(object)
                try self.context.save()
            }
        }
    }
    private func fetch(id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "AudioRecording")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
    private func decode(_ object: NSManagedObject) throws -> AudioRecording {
        var recording = try JSONDecoder().decode(AudioRecording.self, from: object.value(forKey: "payload") as! Data)
        recording.fileURL = files.url(noteID: recording.noteID, recordingID: recording.id)
        return recording
    }
}

extension LithPersistentStore {
    static func makeAudioEntities() -> [NSEntityDescription] {
        let entity = NSEntityDescription()
        entity.name = "AudioRecording"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = [("id", NSAttributeType.UUIDAttributeType), ("noteID", .UUIDAttributeType), ("recordedAt", .dateAttributeType), ("payload", .binaryDataAttributeType)].map { name, type in
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = false
            return attribute
        }
        entity.uniquenessConstraints = [["id"]]
        return [entity]
    }
}
#endif

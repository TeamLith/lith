#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

/// Files cannot share a transaction with Core Data. Persist a UUID-only intent
/// first, then remove the binary only after confirming its metadata is absent.
/// Call under LithStoreWriteLock, using the same store and audio root each time.
struct SyncAudioDeletionJournal: Sendable {
    private struct Intent: Codable {
        let noteID: UUID
        let recordingID: UUID
    }
    let files: AudioFileStore
    init(files: AudioFileStore) { self.files = files }
    private var directory: URL { files.root.appendingPathComponent(".sync-deletions", isDirectory: true) }

    func prepare(_ recording: AudioRecording) throws {
        let intent = Intent(noteID: recording.noteID, recordingID: recording.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(recording.id.uuidString.lowercased()).appendingPathExtension("json")
        try JSONEncoder().encode(intent).write(to: url, options: .atomic)
    }

    func recover(in context: NSManagedObjectContext) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where url.pathExtension == "json" {
            let intent = try JSONDecoder().decode(Intent.self, from: Data(contentsOf: url))
            let request = NSFetchRequest<NSManagedObject>(entityName: "AudioRecording")
            request.predicate = NSPredicate(format: "id == %@", intent.recordingID as CVarArg)
            request.fetchLimit = 1
            if try context.count(for: request) == 0 {
                let file = files.url(noteID: intent.noteID, recordingID: intent.recordingID)
                if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            }
            // If metadata remains, the transaction never committed: retain its file.
            try FileManager.default.removeItem(at: url)
        }
    }
}
#endif

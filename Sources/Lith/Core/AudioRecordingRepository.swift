import Foundation

public protocol AudioRecordingRepository: Sendable {
    func upsert(_ recording: AudioRecording) async throws
    /// Atomically updates a saved recording; never inserts a deleted identifier.
    func update(_ recording: AudioRecording, ifUnchangedSince: Date?) async throws
    func recordings(noteID: UUID?) async throws -> [AudioRecording]
    func recording(id: UUID) async throws -> AudioRecording?
    func delete(recordingID: UUID) async throws
}

public enum AudioRecordingPersistenceError: LocalizedError {
    case missingRecording, changedRecording
    public var errorDescription: String? {
        switch self {
        case .missingRecording: "This recording no longer exists."
        case .changedRecording: "This recording changed in another window or device. Reload it before trying again."
        }
    }
}

public enum RecordingState: String, Codable, Sendable {
    case recording, complete, interrupted, failed
}

/// UUID-derived paths are portable between sandbox containers and devices.
public struct AudioFileStore: Sendable {
    public let root: URL
    public init(root: URL = defaultRoot) { self.root = root }
    public static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lith/Audio", isDirectory: true)
    }
    public static func relativePath(noteID: UUID, recordingID: UUID) -> String {
        "\(noteID.uuidString.lowercased())/\(recordingID.uuidString.lowercased()).m4a"
    }
    public func url(noteID: UUID, recordingID: UUID) -> URL {
        root.appendingPathComponent(Self.relativePath(noteID: noteID, recordingID: recordingID))
    }
    public func prepare(noteID: UUID, recordingID: UUID) throws -> URL {
        let url = url(noteID: noteID, recordingID: recordingID)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return url
    }
    public func remove(_ recording: AudioRecording) throws {
        let url = url(noteID: recording.noteID, recordingID: recording.id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

extension AudioRecording {
    public var relativeFilePath: String { AudioFileStore.relativePath(noteID: noteID, recordingID: id) }
    private enum CodingKeys: String, CodingKey {
        case id, noteID, relativeFilePath, duration, transcript, status, recordedAt, updatedAt, recordingState, errorMessage
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let id = try values.decode(UUID.self, forKey: .id)
        let noteID = try values.decode(UUID.self, forKey: .noteID)
        self.init(id: id, noteID: noteID, fileURL: AudioFileStore().url(noteID: noteID, recordingID: id),
                  duration: try values.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0,
                  transcript: try values.decodeIfPresent(String.self, forKey: .transcript) ?? "",
                  status: try values.decodeIfPresent(TranscriptionStatus.self, forKey: .status) ?? .notStarted,
                  recordedAt: try values.decodeIfPresent(Date.self, forKey: .recordedAt) ?? .distantPast,
                  recordingState: try values.decodeIfPresent(RecordingState.self, forKey: .recordingState) ?? .complete,
                  errorMessage: try values.decodeIfPresent(String.self, forKey: .errorMessage))
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? recordedAt
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(noteID, forKey: .noteID)
        try values.encode(relativeFilePath, forKey: .relativeFilePath)
        try values.encode(duration, forKey: .duration)
        try values.encode(transcript, forKey: .transcript)
        try values.encode(status, forKey: .status)
        try values.encode(recordedAt, forKey: .recordedAt)
        try values.encode(updatedAt, forKey: .updatedAt)
        try values.encode(recordingState, forKey: .recordingState)
        try values.encodeIfPresent(errorMessage, forKey: .errorMessage)
    }
}

import Foundation

public enum SyncState: Sendable {
    case offline
    case syncing
    case synced
    case failed(String)
}

public protocol CloudSyncAdapter: Sendable {
    func sync(notes: [Note], links: [Link]) async throws -> SyncState
}

public protocol AudioCaptureAdapter: Sendable {
    func startRecording(noteID: UUID) async throws -> AudioRecording
    func stopRecording(recordingID: UUID) async throws -> AudioRecording
}

public protocol TranscriptionAdapter: Sendable {
    func transcribe(recording: AudioRecording) async throws -> AudioRecording
}

public protocol SiriIntentAdapter: Sendable {
    func createNote(title: String, content: String) async throws -> Note
    func appendToNote(noteID: UUID, content: String) async throws -> Note
}

public struct NoopCloudSyncAdapter: CloudSyncAdapter {
    public init() {}

    public func sync(notes: [Note], links: [Link]) async throws -> SyncState {
        _ = notes.count + links.count
        return .offline
    }
}

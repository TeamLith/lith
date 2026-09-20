import Foundation

public struct TranscriptionUpdate: Sendable, Equatable {
    public var text: String
    public var isFinal: Bool
    public init(text: String, isFinal: Bool = false) {
        self.text = text
        self.isFinal = isFinal
    }
}

public enum TranscriptionError: LocalizedError {
    case permissionDenied, onDeviceUnavailable, serviceUnavailable, missingAudio, recordingInProgress, alreadyProcessing, missingRecording, incompleteResult
    public var errorDescription: String? {
        switch self {
        case .permissionDenied: "Speech recognition access is denied. Allow access in System Settings to transcribe recordings."
        case .onDeviceUnavailable: "On-device transcription is unavailable for this device or language. Your audio has not been sent to a server."
        case .serviceUnavailable: "Speech recognition is temporarily unavailable. Try again later."
        case .missingAudio: "The audio file is not available on this device."
        case .recordingInProgress: "Stop recording before starting transcription."
        case .alreadyProcessing: "This recording is already being transcribed."
        case .missingRecording: "This recording no longer exists."
        case .incompleteResult: "Speech recognition ended without a final transcript. Try again."
        }
    }
}

@MainActor
public protocol SpeechTranscriptionDriver: Sendable {
    func updates(for fileURL: URL) async throws -> AsyncThrowingStream<TranscriptionUpdate, Error>
}

public protocol TranscriptionServiceProtocol: TranscriptionAdapter {
    func transcribe(recording: AudioRecording, onUpdate: @escaping @Sendable (TranscriptionUpdate) async -> Void) async throws -> AudioRecording
}

public actor TranscriptionService: TranscriptionServiceProtocol {
    private let repository: AudioRecordingRepository
    private let driver: SpeechTranscriptionDriver
    private var processing: Set<UUID> = []
    public init(repository: AudioRecordingRepository, driver: SpeechTranscriptionDriver) {
        self.repository = repository
        self.driver = driver
    }
    public func transcribe(recording: AudioRecording) async throws -> AudioRecording {
        try await transcribe(recording: recording, onUpdate: { _ in })
    }
    public func transcribe(recording: AudioRecording, onUpdate: @escaping @Sendable (TranscriptionUpdate) async -> Void) async throws -> AudioRecording {
        guard processing.insert(recording.id).inserted else { throw TranscriptionError.alreadyProcessing }
        defer { processing.remove(recording.id) }
        guard var current = try await repository.recording(id: recording.id) else { throw TranscriptionError.missingRecording }
        guard current.recordingState != .recording else { throw TranscriptionError.recordingInProgress }
        var persistedAt = current.updatedAt
        current.status = .processing
        current.errorMessage = nil
        current.updatedAt = Date()
        try await repository.update(current, ifUnchangedSince: persistedAt)
        persistedAt = current.updatedAt
        do {
            try Task.checkCancellation()
            guard FileManager.default.fileExists(atPath: current.fileURL.path) else { throw TranscriptionError.missingAudio }
            let updates = try await driver.updates(for: current.fileURL)
            for try await update in updates {
                try Task.checkCancellation()
                current.transcript = update.text
                current.status = update.isFinal ? .complete : .processing
                current.updatedAt = Date()
                try await repository.update(current, ifUnchangedSince: persistedAt)
                persistedAt = current.updatedAt
                await onUpdate(update)
                if update.isFinal { return current }
            }
            try Task.checkCancellation()
            throw TranscriptionError.incompleteResult
        } catch {
            current.status = .failed
            current.errorMessage = error is CancellationError ? "Transcription was cancelled. You can retry." : error.localizedDescription
            current.updatedAt = Date()
            // Do not overwrite a correction or recreate a recording deleted during recognition.
            try? await repository.update(current, ifUnchangedSince: persistedAt)
            throw error
        }
    }

    /// Called after app launch, before presenting saved recordings.
    public func recoverInterruptedTranscriptions() async throws {
        for var recording in try await repository.recordings(noteID: nil)
        where recording.status == .processing && !processing.contains(recording.id) {
            let persistedAt = recording.updatedAt
            recording.status = .failed
            recording.errorMessage = "Transcription stopped when Lith closed. You can retry."
            recording.updatedAt = Date()
            try await repository.update(recording, ifUnchangedSince: persistedAt)
        }
    }
}

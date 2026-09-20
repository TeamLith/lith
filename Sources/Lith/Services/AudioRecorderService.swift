import Foundation

public enum AudioRecordingError: LocalizedError {
    case permissionDenied, alreadyRecording, noActiveRecording, recordingFailed
    public var errorDescription: String? {
        switch self {
        case .permissionDenied: "Microphone access is denied. Allow access in System Settings to record audio."
        case .alreadyRecording: "A recording is already in progress."
        case .noActiveRecording: "No matching recording is in progress."
        case .recordingFailed: "Audio recording could not start. Check the microphone and try again."
        }
    }
}

@MainActor
public protocol AudioRecordingDriver: AnyObject {
    var currentTime: TimeInterval { get }
    var onInterruption: (@MainActor @Sendable (String) -> Void)? { get set }
    func requestPermission() async -> Bool
    func start(at url: URL) throws
    func stop()
}

@MainActor
public final class AudioRecorderService: AudioCaptureAdapter {
    public private(set) var activeRecording: AudioRecording?
    public private(set) var lastError: String?
    public var duration: TimeInterval { max(activeRecording?.duration ?? 0, driver.currentTime) }
    private let repository: AudioRecordingRepository
    private let files: AudioFileStore
    private let driver: AudioRecordingDriver
    private var busy = false
    private var blockedNoteIDs: Set<UUID> = []
    private var deletionGenerations: [UUID: Int] = [:]

    public func blockRecording(noteID: UUID) {
        blockedNoteIDs.insert(noteID)
        deletionGenerations[noteID, default: 0] += 1
    }
    public func unblockRecording(noteID: UUID) { blockedNoteIDs.remove(noteID) }

    public init(repository: AudioRecordingRepository, files: AudioFileStore = AudioFileStore(), driver: AudioRecordingDriver) {
        self.repository = repository
        self.files = files
        self.driver = driver
        driver.onInterruption = { [weak self] message in
            guard let self, let recording = self.activeRecording else { return }
            Task { @MainActor in
                do { _ = try await self.finish(id: recording.id, state: .interrupted, message: message) }
                catch { self.lastError = error.localizedDescription }
            }
        }
    }

    public func startRecording(noteID: UUID) async throws -> AudioRecording {
        guard !blockedNoteIDs.contains(noteID) else { throw AudioRecordingPersistenceError.missingRecording }
        guard activeRecording == nil, !busy else { throw AudioRecordingError.alreadyRecording }
        busy = true
        let generation = deletionGenerations[noteID, default: 0]
        defer { busy = false }
        guard await driver.requestPermission() else { throw AudioRecordingError.permissionDenied }
        try Task.checkCancellation()
        guard !blockedNoteIDs.contains(noteID), generation == deletionGenerations[noteID, default: 0] else { throw AudioRecordingPersistenceError.missingRecording }
        let id = UUID()
        let url = try files.prepare(noteID: noteID, recordingID: id)
        var recording = AudioRecording(id: id, noteID: noteID, fileURL: url, recordingState: .recording)
        // Save before capture, so a crash never leaves an untracked recording file.
        try await repository.upsert(recording)
        guard !blockedNoteIDs.contains(noteID), generation == deletionGenerations[noteID, default: 0] else {
            try await repository.delete(recordingID: id)
            throw AudioRecordingPersistenceError.missingRecording
        }
        do {
            try driver.start(at: url)
            activeRecording = recording
            lastError = nil
            return recording
        } catch {
            driver.stop()
            recording.recordingState = .failed
            recording.errorMessage = error.localizedDescription
            recording.updatedAt = Date()
            try await repository.update(recording, ifUnchangedSince: nil)
            throw error
        }
    }

    public func stopRecording(recordingID: UUID) async throws -> AudioRecording {
        try await finish(id: recordingID, state: .complete, message: nil)
    }

    private func finish(id: UUID, state: RecordingState, message: String?) async throws -> AudioRecording {
        guard var recording = activeRecording, recording.id == id, !busy else { throw AudioRecordingError.noActiveRecording }
        busy = true
        defer { busy = false }
        if recording.recordingState == .recording {
            recording.duration = duration
            recording.recordingState = state
            recording.errorMessage = message
            recording.updatedAt = Date()
        }
        driver.stop()
        activeRecording = recording // Retain metadata if persistence fails; Stop can retry saving.
        do { try await repository.update(recording, ifUnchangedSince: nil) }
        catch AudioRecordingPersistenceError.missingRecording {
            activeRecording = nil
            try? files.remove(recording)
            throw AudioRecordingPersistenceError.missingRecording
        }
        activeRecording = nil
        lastError = recording.errorMessage
        return recording
    }

    /// Finalizes available audio after a platform interruption without restarting capture.
    public func interruptRecording(message: String) async throws -> AudioRecording {
        guard let recording = activeRecording else { throw AudioRecordingError.noActiveRecording }
        return try await finish(id: recording.id, state: .interrupted, message: message)
    }

    /// Restore discoverable metadata after process termination; retain partial audio for playback.
    public func recoverInterruptedRecordings() async throws {
        for var recording in try await repository.recordings(noteID: nil)
        where recording.recordingState == .recording && recording.id != activeRecording?.id {
            recording.recordingState = .interrupted
            recording.errorMessage = "Recording ended when Lith closed. The available audio has been retained."
            recording.updatedAt = Date()
            try await repository.update(recording, ifUnchangedSince: nil)
        }
    }

    public func delete(_ recording: AudioRecording) async throws {
        guard recording.id != activeRecording?.id else { throw AudioRecordingError.alreadyRecording }
        // Preserve the binary if metadata deletion fails. File cleanup is idempotent
        // and can be retried with the same recording if the filesystem rejects it.
        try await repository.delete(recordingID: recording.id)
        try files.remove(recording)
    }
}

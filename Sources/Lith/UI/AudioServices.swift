#if canImport(AVFoundation) && canImport(Speech)
import Foundation

/// One capture and playback owner per app dependency container, shared by every window.
@MainActor
public final class AudioServices {
    public let repository: AudioRecordingRepository
    public let recorder: AudioRecorderService
    public let transcription: TranscriptionService
    public let playback: AudioPlaybackDriver
    public var playingRecordingID: UUID?
    public var playingNoteID: UUID?
    private var operations: [UUID: UUID] = [:]
    private var transcriptionTasks: [UUID: Task<Void, Never>] = [:]
    private var blockedNoteIDs: Set<UUID> = []

    func claim(recordingID: UUID, noteID: UUID) -> Bool {
        guard !blockedNoteIDs.contains(noteID), operations[recordingID] == nil else { return false }
        operations[recordingID] = noteID
        return true
    }
    func release(recordingID: UUID) {
        operations.removeValue(forKey: recordingID)
        transcriptionTasks.removeValue(forKey: recordingID)
    }
    func trackTranscription(_ task: Task<Void, Never>, recordingID: UUID) {
        transcriptionTasks[recordingID] = task
    }
    public func prepareForNoteDeletion(noteID: UUID) async throws {
        blockedNoteIDs.insert(noteID)
        recorder.blockRecording(noteID: noteID)
        let tasks = transcriptionTasks.filter { operations[$0.key] == noteID }.map(\.value)
        tasks.forEach { $0.cancel() }
        for task in tasks { await task.value }
        if let recording = recorder.activeRecording, recording.noteID == noteID {
            _ = try await recorder.stopRecording(recordingID: recording.id)
        }
        if playingNoteID == noteID {
            playback.stop()
            playingRecordingID = nil
            playingNoteID = nil
        }
    }
    public func finishNoteDeletion(noteID: UUID) {
        blockedNoteIDs.remove(noteID)
        recorder.unblockRecording(noteID: noteID)
    }
    private var preparation: Task<Void, Error>?

    public init(repository: AudioRecordingRepository, recorder: AudioRecorderService? = nil,
                transcription: TranscriptionService? = nil, playback: AudioPlaybackDriver? = nil) {
        self.repository = repository
        self.recorder = recorder ?? AudioRecorderService(repository: repository, driver: AppleAudioRecordingDriver())
        self.transcription = transcription ?? TranscriptionService(repository: repository, driver: AppleSpeechTranscriptionDriver())
        self.playback = playback ?? AppleAudioPlaybackDriver()
    }

    public func prepare() async throws {
        if let preparation { return try await preparation.value }
        let task = Task { @MainActor in
            // Preparation runs once before capture. Never classify a live session as abandoned.
            if self.recorder.activeRecording == nil { try await self.recorder.recoverInterruptedRecordings() }
            try await self.transcription.recoverInterruptedTranscriptions()
        }
        preparation = task
        do { try await task.value }
        catch { preparation = nil; throw error }
    }
}
#endif

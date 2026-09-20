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

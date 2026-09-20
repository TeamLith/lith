import Foundation
import Observation

@MainActor @Observable
public final class AudioNoteViewModel {
    public let noteID: UUID
    public private(set) var recordings: [AudioRecording] = []
    public private(set) var activeRecordingID: UUID?
    public private(set) var recordingDuration: TimeInterval = 0
    public private(set) var playingID: UUID?
    public private(set) var isPlaying = false
    public private(set) var playbackTime: TimeInterval = 0
    public private(set) var transcribingID: UUID?
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    private let repository: AudioRecordingRepository
    private let recorder: AudioRecorderService
    private let transcription: TranscriptionServiceProtocol
    private let playback: AudioPlaybackDriver
    private var navigationGeneration = 0
    private var transcriptionTask: Task<Void, Never>?

    public init(noteID: UUID, repository: AudioRecordingRepository, recorder: AudioRecorderService,
                transcription: TranscriptionServiceProtocol, playback: AudioPlaybackDriver) {
        self.noteID = noteID
        self.repository = repository
        self.recorder = recorder
        self.transcription = transcription
        self.playback = playback
    }
    public func load() async {
        do {
            try await recorder.recoverInterruptedRecordings()
            if let service = transcription as? TranscriptionService { try await service.recoverInterruptedTranscriptions() }
            try await reload()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    public func startRecording() async {
        guard !isBusy, activeRecordingID == nil, transcribingID == nil else { return }
        isBusy = true
        let generation = navigationGeneration
        defer { isBusy = false }
        playback.stop()
        playingID = nil
        isPlaying = false
        do {
            let recording = try await recorder.startRecording(noteID: noteID)
            activeRecordingID = recording.id
            if generation != navigationGeneration {
                _ = try await recorder.stopRecording(recordingID: recording.id)
                activeRecordingID = nil
            }
            recordingDuration = 0
            try await reload()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    public func stopRecording() async {
        guard !isBusy, let activeRecordingID else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await recorder.stopRecording(recordingID: activeRecordingID)
            self.activeRecordingID = nil
            try await reload()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    public func tick() async {
        recordingDuration = recorder.duration
        playbackTime = playback.currentTime
        isPlaying = playback.isPlaying
        if activeRecordingID != nil && recorder.activeRecording == nil {
            activeRecordingID = nil
            errorMessage = recorder.lastError
            do { try await reload() } catch { errorMessage = error.localizedDescription }
        }
    }
    public func togglePlayback(_ recording: AudioRecording) {
        guard activeRecordingID == nil else { return }
        do {
            if playingID == recording.id, playback.isPlaying { playback.pause() }
            else {
                if playingID != recording.id { playback.stop() }
                try playback.play(url: recording.fileURL)
                playingID = recording.id
            }
            isPlaying = playback.isPlaying
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    @discardableResult
    public func startTranscription(_ recording: AudioRecording) -> Task<Void, Never>? {
        guard transcribingID == nil, activeRecordingID == nil, !isBusy else { return nil }
        transcribingID = recording.id
        errorMessage = nil
        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.transcribingID = nil; self.transcriptionTask = nil }
            do {
                _ = try await self.transcription.transcribe(recording: recording) { [weak self] _ in
                    await self?.refreshProgress()
                }
                try await self.reload()
            } catch {
                self.errorMessage = error.localizedDescription
                await self.refreshProgress()
            }
        }
        transcriptionTask = task
        return task
    }
    public func cancelTranscription() { transcriptionTask?.cancel() }
    public func saveTranscript(recordingID: UUID, text: String) async {
        guard transcribingID != recordingID else { return }
        do {
            guard var recording = try await repository.recording(id: recordingID) else { throw TranscriptionError.missingRecording }
            recording.transcript = text
            recording.status = .complete
            recording.errorMessage = nil
            recording.updatedAt = Date()
            try await repository.upsert(recording)
            try await reload()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    public func delete(_ recording: AudioRecording) async {
        guard transcribingID != recording.id, activeRecordingID != recording.id else { return }
        do {
            if playingID == recording.id { playback.stop(); playingID = nil; isPlaying = false }
            try await recorder.delete(recording)
            try await reload()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    public func stopForNavigation() async {
        navigationGeneration += 1
        await stopRecording()
        transcriptionTask?.cancel()
        playback.stop()
        isPlaying = false
        playingID = nil
    }
    private func refreshProgress() async {
        do { try await reload() } catch { errorMessage = error.localizedDescription }
    }
    private func reload() async throws { recordings = try await repository.recordings(noteID: noteID) }
}

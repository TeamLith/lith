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
    public private(set) var isRecordingElsewhere = false
    public private(set) var errorMessage: String?
    private let repository: AudioRecordingRepository
    private let recorder: AudioRecorderService
    private let transcription: TranscriptionServiceProtocol
    private let playback: AudioPlaybackDriver
    private var services: AudioServices?
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
    public convenience init(noteID: UUID, services: AudioServices) {
        self.init(noteID: noteID, repository: services.repository, recorder: services.recorder,
                  transcription: services.transcription, playback: services.playback)
        self.services = services
    }
    public func load() async {
        do {
            if let services { try await services.prepare() }
            else {
                try await recorder.recoverInterruptedRecordings()
                if let service = transcription as? TranscriptionService { try await service.recoverInterruptedTranscriptions() }
            }
            try await reload()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    public func startRecording() async {
        guard !isBusy, recorder.activeRecording == nil, transcribingID == nil else { return }
        isBusy = true
        let generation = navigationGeneration
        defer { isBusy = false }
        playback.stop()
        services?.playingRecordingID = nil
        services?.playingNoteID = nil
        playingID = nil
        isPlaying = false
        do {
            try await services?.prepare()
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
        isRecordingElsewhere = recorder.activeRecording != nil && recorder.activeRecording?.id != activeRecordingID
        recordingDuration = activeRecordingID == nil ? 0 : recorder.duration
        if let services {
            playingID = services.playingNoteID == noteID ? services.playingRecordingID : nil
        }
        playbackTime = playingID == nil ? 0 : playback.currentTime
        isPlaying = playingID != nil && playback.isPlaying
        if activeRecordingID != nil && recorder.activeRecording == nil {
            activeRecordingID = nil
            errorMessage = recorder.lastError
            do { try await reload() } catch { errorMessage = error.localizedDescription }
        }
    }
    public func togglePlayback(_ recording: AudioRecording) {
        guard recorder.activeRecording == nil else { return }
        do {
            if playingID == recording.id, playback.isPlaying { playback.pause() }
            else {
                if playingID != recording.id { playback.stop() }
                try playback.play(url: recording.fileURL)
                playingID = recording.id
                services?.playingRecordingID = recording.id
                services?.playingNoteID = noteID
            }
            isPlaying = playback.isPlaying
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    @discardableResult
    public func startTranscription(_ recording: AudioRecording) -> Task<Void, Never>? {
        guard transcribingID == nil, recorder.activeRecording == nil, !isBusy else { return nil }
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
            if playingID == recording.id {
                playback.stop(); playingID = nil; isPlaying = false
                services?.playingRecordingID = nil; services?.playingNoteID = nil
            }
            try await recorder.delete(recording)
            try await reload()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    public func stopForNavigation() async {
        navigationGeneration += 1
        await stopRecording()
        transcriptionTask?.cancel()
        if services == nil || services?.playingNoteID == noteID {
            playback.stop()
            services?.playingRecordingID = nil
            services?.playingNoteID = nil
        }
        isPlaying = false
        playingID = nil
    }
    private func refreshProgress() async {
        do { try await reload() } catch { errorMessage = error.localizedDescription }
    }
    private func reload() async throws { recordings = try await repository.recordings(noteID: noteID) }
}

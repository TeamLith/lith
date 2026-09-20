import Foundation
import Testing
@testable import Lith
#if canImport(CoreData)
import CoreData

@Test @MainActor func audioViewModelRecordsStopsPlaysAndSavesCorrections() async throws {
    let (model, capture, playback, repository, files) = try audioUIFixture()
    defer { try? FileManager.default.removeItem(at: files.root) }
    await model.load()
    await model.startRecording()
    #expect(model.activeRecordingID != nil)
    capture.currentTime = 7
    await model.tick()
    #expect(model.recordingDuration == 7)
    await model.stopRecording()
    #expect(model.activeRecordingID == nil)
    let recording = try #require(model.recordings.first)
    #expect(recording.duration == 7)
    model.togglePlayback(recording)
    #expect(model.isPlaying)
    model.togglePlayback(recording)
    #expect(!model.isPlaying)
    model.togglePlayback(recording)
    #expect(playback.isPlaying)
    await model.saveTranscript(recordingID: recording.id, text: "Corrected words")
    #expect(try await repository.recording(id: recording.id)?.transcript == "Corrected words")
    #expect(try await repository.recording(id: recording.id)?.status == .complete)
    await model.stopForNavigation()
    #expect(!model.isPlaying)
    #expect(model.playingID == nil)
}

@Test @MainActor func audioViewModelExposesPermissionFailureAndAllowsRetry() async throws {
    let (model, capture, _, _, files) = try audioUIFixture()
    defer { try? FileManager.default.removeItem(at: files.root) }
    capture.permission = false
    await model.startRecording()
    #expect(model.errorMessage?.contains("Microphone") == true)
    #expect(model.activeRecordingID == nil)
    capture.permission = true
    await model.startRecording()
    #expect(model.errorMessage == nil)
    #expect(model.activeRecordingID != nil)
    await model.stopForNavigation()
    #expect(model.activeRecordingID == nil)
    #expect(model.recordings.first?.recordingState == .complete)
}

@Test @MainActor func audioViewModelTranscriptionRefreshesTranscriptAndDeletionCleansFiles() async throws {
    let (model, _, _, repository, files) = try audioUIFixture()
    defer { try? FileManager.default.removeItem(at: files.root) }
    await model.startRecording()
    await model.stopRecording()
    let recording = try #require(model.recordings.first)
    let task = try #require(model.startTranscription(recording))
    #expect(model.transcribingID == recording.id)
    #expect(model.startTranscription(recording) == nil)
    await task.value
    #expect(model.transcribingID == nil)
    #expect(model.recordings.first?.transcript == "Final transcript")
    #expect(model.recordings.first?.status == .complete)
    await model.delete(recording)
    #expect(model.recordings.isEmpty)
    #expect(try await repository.recording(id: recording.id) == nil)
    #expect(!FileManager.default.fileExists(atPath: recording.fileURL.path))
}

@Test @MainActor func leavingDuringPermissionPromptStopsNewlyGrantedCapture() async throws {
    let (model, capture, _, _, files) = try audioUIFixture()
    defer { try? FileManager.default.removeItem(at: files.root) }
    capture.delayPermission = true
    let (started, signal) = AsyncStream<Void>.makeStream()
    capture.onPermissionRequest = { signal.yield(()) }
    let start = Task { await model.startRecording() }
    for await _ in started { break }
    signal.finish()
    await model.stopForNavigation()
    capture.permissionContinuation?.resume(returning: true)
    capture.permissionContinuation = nil
    await start.value
    #expect(model.activeRecordingID == nil)
    #expect(model.recordings.first?.recordingState == .complete)
    #expect(!capture.capturing)
}

@Test @MainActor func sharedAudioRuntimeKeepsLiveCaptureWhenAnotherWindowLoads() async throws {
    let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    defer { try? FileManager.default.removeItem(at: files.root) }
    let repository = CoreDataAudioRecordingRepository(container: try makeAudioTestContainer(noteIDs: [audioTestNoteID, UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!]), files: files)
    let capture = UIAudioCaptureDriver(), playback = UIAudioPlaybackDriver()
    let recorder = AudioRecorderService(repository: repository, files: files, driver: capture)
    let services = AudioServices(repository: repository, recorder: recorder, playback: playback)
    let first = AudioNoteViewModel(noteID: audioTestNoteID, services: services)
    let second = AudioNoteViewModel(noteID: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!, services: services)
    await first.load()
    await first.startRecording()
    let id = try #require(first.activeRecordingID)
    await second.load()
    await second.tick()
    #expect(second.isRecordingElsewhere)
    #expect(try await repository.recording(id: id)?.recordingState == .recording)
    await second.startRecording()
    #expect(second.activeRecordingID == nil)
    await second.stopForNavigation()
    #expect(capture.capturing)
    await first.stopRecording()
    let recording = try #require(first.recordings.first)
    first.togglePlayback(recording)
    #expect(playback.isPlaying)
    await second.stopForNavigation()
    #expect(playback.isPlaying)
    await second.startRecording()
    #expect(!playback.isPlaying)
    #expect(second.activeRecordingID != nil)
    await second.stopRecording()
}

@MainActor private func audioUIFixture() throws -> (AudioNoteViewModel, UIAudioCaptureDriver, UIAudioPlaybackDriver, CoreDataAudioRecordingRepository, AudioFileStore) {
    let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let repository = CoreDataAudioRecordingRepository(container: try makeAudioTestContainer(noteIDs: [audioTestNoteID, UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!]), files: files)
    let capture = UIAudioCaptureDriver(), playback = UIAudioPlaybackDriver()
    let recorder = AudioRecorderService(repository: repository, files: files, driver: capture)
    let model = AudioNoteViewModel(noteID: audioTestNoteID, repository: repository, recorder: recorder,
                                  transcription: UITranscriptionService(repository: repository), playback: playback)
    return (model, capture, playback, repository, files)
}

@MainActor private final class UIAudioCaptureDriver: AudioRecordingDriver {
    var currentTime: TimeInterval = 0
    var onInterruption: (@MainActor @Sendable (String) -> Void)?
    var permission = true
    var capturing = false
    var delayPermission = false
    var permissionContinuation: CheckedContinuation<Bool, Never>?
    var onPermissionRequest: (() -> Void)?
    func requestPermission() async -> Bool {
        if delayPermission {
            return await withCheckedContinuation { permissionContinuation = $0; onPermissionRequest?() }
        }
        return permission
    }
    func start(at url: URL) throws { try Data("audio".utf8).write(to: url); capturing = true }
    func stop() { currentTime = 0; capturing = false }
}

@MainActor private final class UIAudioPlaybackDriver: AudioPlaybackDriver {
    var currentTime: TimeInterval = 0
    var isPlaying = false
    func play(url: URL) throws { isPlaying = true }
    func pause() { isPlaying = false }
    func stop() { isPlaying = false; currentTime = 0 }
}

private actor UITranscriptionService: TranscriptionServiceProtocol {
    let repository: AudioRecordingRepository
    init(repository: AudioRecordingRepository) { self.repository = repository }
    func transcribe(recording: AudioRecording) async throws -> AudioRecording {
        try await transcribe(recording: recording, onUpdate: { _ in })
    }
    func transcribe(recording: AudioRecording, onUpdate: @escaping @Sendable (TranscriptionUpdate) async -> Void) async throws -> AudioRecording {
        var value = recording
        value.status = .processing
        value.transcript = "Partial transcript"
        try await repository.upsert(value)
        await onUpdate(.init(text: value.transcript))
        value.status = .complete
        value.transcript = "Final transcript"
        try await repository.upsert(value)
        await onUpdate(.init(text: value.transcript, isFinal: true))
        return value
    }
}

@Test @MainActor func sharedTranscriptionBlocksCorrectionsAndDeletionFromAnotherWindow() async throws {
    let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    defer { try? FileManager.default.removeItem(at: files.root) }
    let repository = CoreDataAudioRecordingRepository(container: try makeAudioTestContainer(), files: files)
    let speech = ControlledAudioSpeechDriver()
    let recorder = AudioRecorderService(repository: repository, files: files, driver: UIAudioCaptureDriver())
    let services = AudioServices(repository: repository, recorder: recorder,
                                 transcription: TranscriptionService(repository: repository, driver: speech), playback: UIAudioPlaybackDriver())
    let first = AudioNoteViewModel(noteID: audioTestNoteID, services: services)
    let second = AudioNoteViewModel(noteID: audioTestNoteID, services: services)
    await first.load()
    await first.startRecording()
    await first.stopRecording()
    let recording = try #require(first.recordings.first)
    let task = try #require(first.startTranscription(recording))
    await speech.waitUntilStarted()
    await second.saveTranscript(recordingID: recording.id, text: "Correction")
    #expect(second.errorMessage?.contains("already") == true)
    await second.delete(recording)
    #expect(try await repository.recording(id: recording.id) != nil)
    #expect(FileManager.default.fileExists(atPath: recording.fileURL.path))
    speech.continuation?.yield(.init(text: "Recognized", isFinal: true))
    await task.value
    await second.saveTranscript(recordingID: recording.id, text: "Correction")
    #expect(try await repository.recording(id: recording.id)?.transcript == "Correction")
    await second.delete(recording)
    #expect(try await repository.recording(id: recording.id) == nil)
}

@Test @MainActor func noteDeletionCancelsTranscriptionAndInvalidatesPendingMicrophonePermission() async throws {
    let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    defer { try? FileManager.default.removeItem(at: files.root) }
    let repository = CoreDataAudioRecordingRepository(container: try makeAudioTestContainer(), files: files)
    let speech = ControlledAudioSpeechDriver(), capture = UIAudioCaptureDriver()
    let recorder = AudioRecorderService(repository: repository, files: files, driver: capture)
    let services = AudioServices(repository: repository, recorder: recorder,
                                 transcription: TranscriptionService(repository: repository, driver: speech), playback: UIAudioPlaybackDriver())
    let model = AudioNoteViewModel(noteID: audioTestNoteID, services: services)
    await model.load()
    await model.startRecording()
    await model.stopRecording()
    let recording = try #require(model.recordings.first)
    let task = try #require(model.startTranscription(recording))
    await speech.waitUntilStarted()
    try await services.prepareForNoteDeletion(noteID: audioTestNoteID)
    try await repository.delete(recordingID: recording.id)
    services.finishNoteDeletion(noteID: audioTestNoteID)
    speech.continuation?.yield(.init(text: "Too late", isFinal: true))
    await task.value
    #expect(try await repository.recording(id: recording.id) == nil)
    capture.delayPermission = true
    let (requested, signal) = AsyncStream<Void>.makeStream()
    capture.onPermissionRequest = { signal.yield(()); signal.finish() }
    let start = Task { await model.startRecording() }
    for await _ in requested { break }
    try await services.prepareForNoteDeletion(noteID: audioTestNoteID)
    services.finishNoteDeletion(noteID: audioTestNoteID)
    capture.permissionContinuation?.resume(returning: true)
    await start.value
    #expect(!capture.capturing)
    #expect(try await repository.recordings(noteID: audioTestNoteID).isEmpty)
}

@MainActor private final class ControlledAudioSpeechDriver: SpeechTranscriptionDriver {
    var continuation: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation?
    private let started = AsyncStream<Void>.makeStream()
    func waitUntilStarted() async { for await _ in started.stream { break } }
    func updates(for fileURL: URL) async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        let pair = AsyncThrowingStream<TranscriptionUpdate, Error>.makeStream()
        continuation = pair.continuation
        started.continuation.yield(())
        started.continuation.finish()
        return pair.stream
    }
}
#endif

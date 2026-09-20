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
    let repository = CoreDataAudioRecordingRepository(container: try LithPersistentStore.makeContainer(inMemory: true), files: files)
    let capture = UIAudioCaptureDriver(), playback = UIAudioPlaybackDriver()
    let recorder = AudioRecorderService(repository: repository, files: files, driver: capture)
    let services = AudioServices(repository: repository, recorder: recorder, playback: playback)
    let first = AudioNoteViewModel(noteID: UUID(), services: services)
    let second = AudioNoteViewModel(noteID: UUID(), services: services)
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
    let repository = CoreDataAudioRecordingRepository(container: try LithPersistentStore.makeContainer(inMemory: true), files: files)
    let capture = UIAudioCaptureDriver(), playback = UIAudioPlaybackDriver()
    let recorder = AudioRecorderService(repository: repository, files: files, driver: capture)
    let model = AudioNoteViewModel(noteID: UUID(), repository: repository, recorder: recorder,
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
#endif

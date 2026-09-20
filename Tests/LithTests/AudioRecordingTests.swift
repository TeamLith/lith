import Foundation
import Testing
@testable import Lith
#if canImport(CoreData)
import CoreData

@Test func audioMetadataSurvivesRepositoryReloadAndUsesPortablePaths() async throws {
    let container = try LithPersistentStore.makeContainer(inMemory: true)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let files = AudioFileStore(root: root)
    let repository = CoreDataAudioRecordingRepository(container: container, files: files)
    let noteID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    let id = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    var recording = AudioRecording(id: id, noteID: noteID, fileURL: URL(fileURLWithPath: "/other-device/private/audio.m4a"), duration: 12, transcript: "hello", status: .complete, recordingState: .interrupted, errorMessage: "interrupted")
    recording.updatedAt = Date(timeIntervalSince1970: 123)
    try await repository.upsert(recording)
    let reloaded = CoreDataAudioRecordingRepository(container: container, files: files)
    let saved = try #require(await reloaded.recording(id: id))
    #expect(saved.relativeFilePath == "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb.m4a")
    #expect(saved.fileURL == root.appendingPathComponent(saved.relativeFilePath))
    #expect(saved.transcript == "hello")
    #expect(saved.recordingState == .interrupted)
    #expect(saved.errorMessage == "interrupted")
    #expect(saved.updatedAt == recording.updatedAt)
    let encoded = String(decoding: try JSONEncoder().encode(recording), as: UTF8.self)
    #expect(!encoded.contains("other-device"))
    #expect(try await reloaded.recordings(noteID: UUID()).isEmpty)
    try await reloaded.delete(recordingID: id)
    #expect(try await reloaded.recording(id: id) == nil)
}

@Test @MainActor func recordingPersistsStartStopAndRejectsConcurrentCapture() async throws {
    let (service, driver, repository, files) = try audioFixture()
    defer { try? FileManager.default.removeItem(at: files.root) }
    let recording = try await service.startRecording(noteID: UUID())
    #expect(try await repository.recording(id: recording.id)?.recordingState == .recording)
    await #expect(throws: AudioRecordingError.self) { try await service.startRecording(noteID: UUID()) }
    driver.currentTime = 4.5
    let finished = try await service.stopRecording(recordingID: recording.id)
    #expect(finished.duration == 4.5)
    #expect(finished.recordingState == .complete)
    #expect(service.activeRecording == nil)
    #expect(FileManager.default.fileExists(atPath: finished.fileURL.path))
    try await service.delete(finished)
    #expect(!FileManager.default.fileExists(atPath: finished.fileURL.path))
    #expect(try await repository.recording(id: finished.id) == nil)
}

@Test @MainActor func recordingPermissionAndDriverFailuresAreRecoverable() async throws {
    let (service, driver, repository, files) = try audioFixture()
    defer { try? FileManager.default.removeItem(at: files.root) }
    driver.permission = false
    await #expect(throws: AudioRecordingError.self) { try await service.startRecording(noteID: UUID()) }
    #expect(try await repository.recordings(noteID: nil).isEmpty)
    driver.permission = true
    driver.failStart = true
    await #expect(throws: AudioRecordingError.self) { try await service.startRecording(noteID: UUID()) }
    let failed = try #require(await repository.recordings(noteID: nil).first)
    #expect(failed.recordingState == .failed)
    #expect(failed.errorMessage != nil)
    driver.failStart = false
    let recording = try await service.startRecording(noteID: UUID())
    _ = try await service.stopRecording(recordingID: recording.id)
}

@Test @MainActor func abandonedRecordingIsMarkedInterruptedWithoutDeletingAudio() async throws {
    let (service, _, repository, files) = try audioFixture()
    defer { try? FileManager.default.removeItem(at: files.root) }
    let id = UUID(), noteID = UUID()
    let url = try files.prepare(noteID: noteID, recordingID: id)
    try Data("partial audio".utf8).write(to: url)
    try await repository.upsert(AudioRecording(id: id, noteID: noteID, fileURL: url, recordingState: .recording))
    try await service.recoverInterruptedRecordings()
    #expect(try await repository.recording(id: id)?.recordingState == .interrupted)
    #expect(FileManager.default.fileExists(atPath: url.path))
}

@Test @MainActor func interruptedSaveRetryPreservesTerminalStateAndFailedDeletionRetainsAudio() async throws {
    let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    defer { try? FileManager.default.removeItem(at: files.root) }
    let storage = CoreDataAudioRecordingRepository(container: try LithPersistentStore.makeContainer(inMemory: true), files: files)
    let repository = FailingAudioRepository(base: storage)
    let driver = TestAudioDriver()
    let service = AudioRecorderService(repository: repository, files: files, driver: driver)
    let recording = try await service.startRecording(noteID: UUID())
    driver.currentTime = 9
    await repository.setFailure(upsert: true, delete: false)
    await #expect(throws: AudioRecordingError.self) { try await service.interruptRecording(message: "Phone call") }
    #expect(service.activeRecording?.recordingState == .interrupted)
    await repository.setFailure(upsert: false, delete: false)
    let saved = try await service.stopRecording(recordingID: recording.id)
    #expect(saved.recordingState == .interrupted)
    #expect(saved.duration == 9)
    #expect(saved.errorMessage == "Phone call")
    await repository.setFailure(upsert: false, delete: true)
    await #expect(throws: AudioRecordingError.self) { try await service.delete(saved) }
    #expect(FileManager.default.fileExists(atPath: saved.fileURL.path))
    #expect(try await storage.recording(id: saved.id) != nil)
    await repository.setFailure(upsert: false, delete: false)
    try await service.delete(saved)
    #expect(!FileManager.default.fileExists(atPath: saved.fileURL.path))
}

private actor FailingAudioRepository: AudioRecordingRepository {
    let base: AudioRecordingRepository
    var failUpsert = false
    var failDelete = false
    init(base: AudioRecordingRepository) { self.base = base }
    func setFailure(upsert: Bool, delete: Bool) { failUpsert = upsert; failDelete = delete }
    func upsert(_ recording: AudioRecording) async throws {
        if failUpsert { throw AudioRecordingError.recordingFailed }
        try await base.upsert(recording)
    }
    func delete(recordingID: UUID) async throws {
        if failDelete { throw AudioRecordingError.recordingFailed }
        try await base.delete(recordingID: recordingID)
    }
    func recording(id: UUID) async throws -> AudioRecording? { try await base.recording(id: id) }
    func recordings(noteID: UUID?) async throws -> [AudioRecording] { try await base.recordings(noteID: noteID) }
}

@MainActor private func audioFixture() throws -> (AudioRecorderService, TestAudioDriver, CoreDataAudioRecordingRepository, AudioFileStore) {
    let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let repository = CoreDataAudioRecordingRepository(container: try LithPersistentStore.makeContainer(inMemory: true), files: files)
    let driver = TestAudioDriver()
    return (AudioRecorderService(repository: repository, files: files, driver: driver), driver, repository, files)
}

@MainActor private final class TestAudioDriver: AudioRecordingDriver {
    var currentTime: TimeInterval = 0
    var onInterruption: (@MainActor @Sendable (String) -> Void)?
    var permission = true
    var failStart = false
    func requestPermission() async -> Bool { permission }
    func start(at url: URL) throws {
        if failStart { throw AudioRecordingError.recordingFailed }
        try Data("audio".utf8).write(to: url)
    }
    func stop() { currentTime = 0 }
}
#endif

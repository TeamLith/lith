import Foundation
import Testing
@testable import Lith
#if canImport(CoreData)
import CoreData

@Test @MainActor func transcriptionPersistsPartialAndFinalBeforeNotifyingConsumer() async throws {
    let driver = FakeSpeechDriver(updates: [.init(text: "A partial"), .init(text: "A final transcript", isFinal: true)])
    let (service, repository, recording, files) = try await transcriptionFixture(driver: driver)
    defer { try? FileManager.default.removeItem(at: files.root) }
    let observed = TranscriptionObservations()
    let completed = try await service.transcribe(recording: recording) { update in
        let saved = try? await repository.recording(id: recording.id)
        await observed.append(update, persisted: saved?.status)
    }
    #expect(completed.status == .complete)
    #expect(completed.transcript == "A final transcript")
    #expect(completed.errorMessage == nil)
    #expect(await observed.statuses == [.processing, .complete])
    #expect(await observed.updates.map(\.text) == ["A partial", "A final transcript"])
}

@Test(arguments: [TranscriptionError.permissionDenied, .onDeviceUnavailable, .serviceUnavailable])
@MainActor func transcriptionFailurePersistsRetryableStatusAndRetainsAudio(failure: TranscriptionError) async throws {
    let driver = FakeSpeechDriver(failure: failure)
    let (service, repository, recording, files) = try await transcriptionFixture(driver: driver)
    defer { try? FileManager.default.removeItem(at: files.root) }
    await #expect(throws: TranscriptionError.self) { try await service.transcribe(recording: recording) }
    let failed = try #require(await repository.recording(id: recording.id))
    #expect(failed.status == .failed)
    #expect(failed.errorMessage == failure.localizedDescription)
    #expect(FileManager.default.fileExists(atPath: recording.fileURL.path))
    driver.failure = nil
    driver.values = [.init(text: "Retried", isFinal: true)]
    let retried = try await service.transcribe(recording: recording)
    #expect(retried.status == .complete)
    #expect(retried.transcript == "Retried")
}

@Test @MainActor func transcriptionRejectsMissingFileAndRecordingInProgress() async throws {
    let driver = FakeSpeechDriver()
    let (service, repository, recording, files) = try await transcriptionFixture(driver: driver)
    defer { try? FileManager.default.removeItem(at: files.root) }
    var active = recording
    active.recordingState = .recording
    try await repository.upsert(active)
    await #expect(throws: TranscriptionError.self) { try await service.transcribe(recording: active) }
    try await repository.upsert(recording)
    try files.remove(recording)
    await #expect(throws: TranscriptionError.self) { try await service.transcribe(recording: recording) }
    #expect(try await repository.recording(id: recording.id)?.status == .failed)
    #expect(driver.calls == 0)
}

@Test @MainActor func transcriptionCancellationAndConcurrentRequestPreserveRetryableState() async throws {
    let driver = FakeSpeechDriver(stayOpen: true)
    let (started, signal) = AsyncStream<Void>.makeStream()
    driver.onStart = { signal.yield(()) }
    let (service, repository, recording, files) = try await transcriptionFixture(driver: driver)
    defer { try? FileManager.default.removeItem(at: files.root) }
    let task = Task { try await service.transcribe(recording: recording) }
    for await _ in started { break }
    signal.finish()
    await #expect(throws: TranscriptionError.self) { try await service.transcribe(recording: recording) }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(try await repository.recording(id: recording.id)?.status == .failed)
    #expect(try await repository.recording(id: recording.id)?.errorMessage?.contains("cancelled") == true)
}

@Test @MainActor func incompleteTranscriptionAndAbandonedProcessingBecomeFailed() async throws {
    let driver = FakeSpeechDriver(updates: [.init(text: "Partial only")])
    let (service, repository, recording, files) = try await transcriptionFixture(driver: driver)
    defer { try? FileManager.default.removeItem(at: files.root) }
    await #expect(throws: TranscriptionError.self) { try await service.transcribe(recording: recording) }
    #expect(try await repository.recording(id: recording.id)?.transcript == "Partial only")
    var abandoned = recording
    abandoned.status = .processing
    try await repository.upsert(abandoned)
    try await service.recoverInterruptedTranscriptions()
    #expect(try await repository.recording(id: recording.id)?.status == .failed)
}


@Test @MainActor func externalDeletionDuringRecognitionDoesNotResurrectMetadata() async throws {
    let driver = FakeSpeechDriver(updates: [.init(text: "Partial"), .init(text: "Late final", isFinal: true)])
    let (service, repository, recording, files) = try await transcriptionFixture(driver: driver)
    defer { try? FileManager.default.removeItem(at: files.root) }
    await #expect(throws: AudioRecordingPersistenceError.self) {
        try await service.transcribe(recording: recording) { update in
            if !update.isFinal { try? await repository.delete(recordingID: recording.id) }
        }
    }
    #expect(try await repository.recording(id: recording.id) == nil)
}

@Test @MainActor func externalCorrectionDuringRecognitionIsNotOverwrittenByLateResults() async throws {
    let driver = FakeSpeechDriver(updates: [.init(text: "Partial"), .init(text: "Late final", isFinal: true)])
    let (service, repository, recording, files) = try await transcriptionFixture(driver: driver)
    defer { try? FileManager.default.removeItem(at: files.root) }
    await #expect(throws: AudioRecordingPersistenceError.self) {
        try await service.transcribe(recording: recording) { update in
            if !update.isFinal, var saved = try? await repository.recording(id: recording.id) {
                let previous = saved.updatedAt
                saved.transcript = "Manual correction"
                saved.updatedAt = previous.addingTimeInterval(1)
                try? await repository.update(saved, ifUnchangedSince: previous)
            }
        }
    }
    #expect(try await repository.recording(id: recording.id)?.transcript == "Manual correction")
}

@MainActor private func transcriptionFixture(driver: SpeechTranscriptionDriver) async throws -> (TranscriptionService, CoreDataAudioRecordingRepository, AudioRecording, AudioFileStore) {
    let files = AudioFileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let repository = CoreDataAudioRecordingRepository(container: try makeAudioTestContainer(), files: files)
    let id = UUID(), noteID = audioTestNoteID
    let fileURL = try files.prepare(noteID: noteID, recordingID: id)
    try Data("recorded audio".utf8).write(to: fileURL)
    let recording = AudioRecording(id: id, noteID: noteID, fileURL: fileURL, duration: 5)
    try await repository.upsert(recording)
    return (TranscriptionService(repository: repository, driver: driver), repository, recording, files)
}

@MainActor private final class FakeSpeechDriver: SpeechTranscriptionDriver {
    var values: [TranscriptionUpdate]
    var failure: TranscriptionError?
    var stayOpen: Bool
    var calls = 0
    var onStart: (@Sendable () -> Void)?
    init(updates: [TranscriptionUpdate] = [], failure: TranscriptionError? = nil, stayOpen: Bool = false) {
        self.values = updates; self.failure = failure; self.stayOpen = stayOpen
    }
    func updates(for fileURL: URL) async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        calls += 1
        if let failure { throw failure }
        let (stream, continuation) = AsyncThrowingStream<TranscriptionUpdate, Error>.makeStream()
        values.forEach { continuation.yield($0) }
        if !stayOpen { continuation.finish() }
        onStart?()
        return stream
    }
}

private actor TranscriptionObservations {
    var statuses: [TranscriptionStatus?] = []
    var updates: [TranscriptionUpdate] = []
    func append(_ update: TranscriptionUpdate, persisted: TranscriptionStatus?) {
        updates.append(update); statuses.append(persisted)
    }
}
#endif

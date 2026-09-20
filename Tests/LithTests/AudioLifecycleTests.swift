import Foundation
import Testing
@testable import Lith
#if canImport(CoreData)
import CoreData

let audioTestNoteID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
func makeAudioTestContainer(noteIDs: [UUID] = [audioTestNoteID]) throws -> NSPersistentContainer {
    let container = try LithPersistentStore.makeContainer(inMemory: true)
    try container.viewContext.performAndWait {
        for id in noteIDs {
            try ManagedNote(context: container.viewContext).apply(Note(id: id, title: "Audio parent", bodyMarkdown: ""))
        }
        try container.viewContext.save()
    }
    return container
}

@Test func audioUpdatesRejectDeletedRecordsAndStaleCorrectionsAcrossRepositories() async throws {
    let container = try makeAudioTestContainer()
    let first = CoreDataAudioRecordingRepository(container: container)
    let second = CoreDataAudioRecordingRepository(container: container)
    var recording = AudioRecording(noteID: audioTestNoteID, fileURL: URL(fileURLWithPath: "/unused"))
    try await first.upsert(recording)
    let prior = recording.updatedAt
    recording.transcript = "Manual correction"
    recording.updatedAt = prior.addingTimeInterval(1)
    try await second.update(recording, ifUnchangedSince: prior)
    var stale = recording
    stale.transcript = "Late partial"
    await #expect(throws: AudioRecordingPersistenceError.self) { try await first.update(stale, ifUnchangedSince: prior) }
    #expect(try await second.recording(id: recording.id)?.transcript == "Manual correction")
    try await second.delete(recordingID: recording.id)
    await #expect(throws: AudioRecordingPersistenceError.self) { try await first.update(stale, ifUnchangedSince: nil) }
    #expect(try await first.recording(id: recording.id) == nil)
}

@Test func audioWritesRequireAnExistingParentNote() async throws {
    let container = try makeAudioTestContainer()
    let repository = CoreDataAudioRecordingRepository(container: container)
    let recording = AudioRecording(noteID: audioTestNoteID, fileURL: URL(fileURLWithPath: "/unused"))
    try await repository.upsert(recording)
    try await CoreDataNoteRepository(container: container).delete(noteID: audioTestNoteID)
    await #expect(throws: AudioRecordingPersistenceError.self) { try await repository.update(recording, ifUnchangedSince: nil) }
    await #expect(throws: AudioRecordingPersistenceError.self) { try await repository.upsert(recording) }
    let unknown = AudioRecording(noteID: UUID(), fileURL: URL(fileURLWithPath: "/unused"))
    await #expect(throws: AudioRecordingPersistenceError.self) { try await repository.upsert(unknown) }
    #expect(try await repository.recording(id: unknown.id) == nil)
}
#endif

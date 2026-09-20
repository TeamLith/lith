import Foundation
import Testing
@testable import Lith
#if canImport(CloudKit)
import CloudKit
#endif

@Test func cloudRecordRoundTripsNoteAndPreservesStableIdentity() throws {
    let note = Note(title: "Linked", bodyMarkdown: "[[Other]]", tags: ["swift", "work"], metadata: ["sourceURL": "https://example.com"])
    let value = try CloudRecord.encode(note, kind: .note, id: note.id, modifiedAt: note.updatedAt)
    #expect(try value.decode(Note.self) == note)
    #expect(value.id == "LithNote:\(note.id.uuidString.lowercased())")
    #if canImport(CloudKit)
    #expect(try CloudKitRecordMapper.decode(CloudKitRecordMapper.encode(value)) == value)
    #endif
}

@Test func cloudSchemaRejectsFutureVersionAndPreservesDeletionIdentity() throws {
    let note = Note(title: "A", bodyMarkdown: "B")
    let record = try CloudRecord.encode(note, kind: .note, id: note.id, modifiedAt: note.updatedAt)
    let deletion = try record.tombstone(at: Date())
    #expect(deletion.id == record.id)
    #expect(deletion.deleted)
    #expect(throws: CloudRecordError.self) { try deletion.decode(Note.self) }
    #expect(throws: CloudRecordError.self) {
        try CloudRecord(kind: .note, entityID: note.id, modifiedAt: Date(), payload: record.payload, version: 2)
    }
}

@Test func cloudSchemaCanonicalizesTagsAndRejectsOversizedPayload() throws {
    let note = Note(title: "A", bodyMarkdown: "B", tags: ["c", "a", "b"])
    let value = try CloudRecord.encode(note, kind: .note, id: note.id, modifiedAt: note.updatedAt)
    let json = try #require(JSONSerialization.jsonObject(with: value.payload) as? [String: Any])
    #expect(json["tags"] as? [String] == ["a", "b", "c"])
    #expect(throws: CloudRecordError.self) {
        try CloudRecord(kind: .note, entityID: note.id, modifiedAt: Date(), payload: Data(repeating: 0, count: 750_001))
    }
    #expect(Set(CloudRecord.Kind.allCases.map(\.rawValue)).count == 7)
}

@Test func cloudSchemaRejectsMismatchedPayloadIdentityAndType() throws {
    let note = Note(title: "A", bodyMarkdown: "B")
    #expect(throws: CloudRecordError.self) {
        try CloudRecord.encode(note, kind: .note, id: UUID(), modifiedAt: note.updatedAt)
    }
    #expect(throws: DecodingError.self) {
        try CloudRecord.encode(note, kind: .feed, id: note.id, modifiedAt: note.updatedAt)
    }
}

import Foundation

/// Versioned wire envelope shared by the local store and the private CloudKit zone.
public struct CloudRecord: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case note = "LithNote", tag = "LithTag", link = "LithLink"
        case feed = "LithRSSFeed", item = "LithRSSItem"
        case audio = "LithAudioRecording", action = "LithActionItem"
    }

    public static let schemaVersion = 1
    public static let zoneName = "LithPrivateV1"
    public static let maximumPayloadBytes = 750_000
    public let kind: Kind
    public let entityID: UUID
    public let version: Int
    public var modifiedAt: Date
    public var deleted: Bool
    public var payload: Data
    public var id: String { "\(kind.rawValue):\(entityID.uuidString.lowercased())" }

    public init(kind: Kind, entityID: UUID, modifiedAt: Date, deleted: Bool = false, payload: Data, version: Int = schemaVersion) throws {
        self.kind = kind
        self.entityID = entityID
        self.version = version
        self.modifiedAt = modifiedAt
        self.deleted = deleted
        self.payload = payload
        try validate()
    }

    public func validate() throws {
        guard version == Self.schemaVersion else { throw CloudRecordError.unsupportedVersion(version) }
        guard modifiedAt.timeIntervalSince1970.isFinite else { throw CloudRecordError.invalidRecord }
        guard payload.count <= Self.maximumPayloadBytes else { throw CloudRecordError.payloadTooLarge }
        if !deleted {
            let decoder = JSONDecoder()
            let payloadID: UUID
            switch kind {
            case .note: payloadID = try decoder.decode(Note.self, from: payload).id
            case .tag: payloadID = try decoder.decode(CloudTag.self, from: payload).id
            case .link: payloadID = try decoder.decode(Link.self, from: payload).id
            case .feed: payloadID = try decoder.decode(RSSFeed.self, from: payload).id
            case .item: payloadID = try decoder.decode(RSSItem.self, from: payload).id
            case .audio: payloadID = try decoder.decode(AudioRecording.self, from: payload).id
            case .action: payloadID = try decoder.decode(ActionItem.self, from: payload).id
            }
            guard payloadID == entityID else { throw CloudRecordError.invalidRecord }
        }
    }

    public static func encode<T: Encodable>(_ value: T, kind: Kind, id: UUID, modifiedAt: Date) throws -> Self {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Sets (note tags) have no stable encoding order. Canonicalize only that field.
        var data = try encoder.encode(value)
        if kind == .note, var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tags = object["tags"] as? [String] {
            object["tags"] = tags.sorted()
            data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
        return try Self(kind: kind, entityID: id, modifiedAt: modifiedAt, payload: data)
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try validate()
        guard !deleted else { throw CloudRecordError.deletedRecord }
        return try JSONDecoder().decode(type, from: payload)
    }

    public func tombstone(at date: Date) throws -> Self {
        try Self(kind: kind, entityID: entityID, modifiedAt: date, deleted: true, payload: Data())
    }
}

public struct CloudTag: Codable, Sendable {
    public let id: UUID
    public let name: String
    public init(id: UUID, name: String) { self.id = id; self.name = name }
}

public enum CloudRecordError: Error, LocalizedError {
    case unsupportedVersion(Int), invalidRecord, payloadTooLarge, deletedRecord
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This iCloud data requires a newer version of Lith."
        case .invalidRecord: "The iCloud record is invalid. Local data has been kept."
        case .payloadTooLarge: "An item is too large to sync. Its local copy has been kept."
        case .deletedRecord: "This iCloud item has been deleted."
        }
    }
}

#if canImport(CloudKit)
@preconcurrency import CloudKit

public enum CloudKitRecordMapper {
    public static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: CloudRecord.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// Updating the fetched record preserves the server change tag for optimistic locking.
    public static func encode(_ value: CloudRecord, updating record: CKRecord? = nil) throws -> CKRecord {
        try value.validate()
        let recordID = CKRecord.ID(recordName: value.id, zoneID: zoneID)
        let result = record ?? CKRecord(recordType: value.kind.rawValue, recordID: recordID)
        guard result.recordID == recordID, result.recordType == value.kind.rawValue else { throw CloudRecordError.invalidRecord }
        result["schemaVersion"] = value.version as CKRecordValue
        result["entityID"] = value.entityID.uuidString.lowercased() as CKRecordValue
        result["modifiedAt"] = value.modifiedAt as CKRecordValue
        result["deleted"] = (value.deleted ? 1 : 0) as CKRecordValue
        result["payload"] = value.payload as CKRecordValue
        return result
    }

    public static func decode(_ record: CKRecord) throws -> CloudRecord {
        guard let kind = CloudRecord.Kind(rawValue: record.recordType),
              let rawID = record["entityID"] as? String, let id = UUID(uuidString: rawID),
              let version = record["schemaVersion"] as? Int,
              let modifiedAt = record["modifiedAt"] as? Date,
              let deleted = record["deleted"] as? Int,
              let payload = record["payload"] as? Data else { throw CloudRecordError.invalidRecord }
        let value = try CloudRecord(kind: kind, entityID: id, modifiedAt: modifiedAt, deleted: deleted != 0, payload: payload, version: version)
        guard record.recordID.recordName == value.id, record.recordID.zoneID == zoneID else { throw CloudRecordError.invalidRecord }
        return value
    }
}
#endif

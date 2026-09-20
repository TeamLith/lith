#if canImport(CloudKit)
@preconcurrency import CloudKit
import Foundation

/// Uses only the user's private database; an app-owned container must be configured by the release owner.
public actor AppleCloudKitTransport: SyncTransport {
    private let container: CKContainer
    private var database: CKDatabase { container.privateCloudDatabase }
    public init(containerIdentifier: String) throws {
        guard containerIdentifier.hasPrefix("iCloud."), containerIdentifier.count > 7 else {
            throw SyncEngineError.configuration("Configure an Apple-owned iCloud container before enabling sync.")
        }
        container = CKContainer(identifier: containerIdentifier)
    }

    public func accountID() async throws -> String {
        do {
            guard try await container.accountStatus() == .available else { throw SyncEngineError.accountUnavailable }
            return try await container.userRecordID().recordName
        } catch { throw mapped(error) }
    }
    public func prepareZone() async throws {
        do { _ = try await database.save(CKRecordZone(zoneID: CloudKitRecordMapper.zoneID)) }
        catch { throw mapped(error) }
    }
    public func changes(since token: Data?) async throws -> SyncChangePage {
        do {
            let decoded = try token.map { try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0) }
            let page = try await database.recordZoneChanges(inZoneWith: CloudKitRecordMapper.zoneID,
                                                           since: decoded ?? nil, resultsLimit: 200)
            // Lith deletes with tombstones. A physical deletion means the zone was modified externally;
            // don't guess deletion times or resurrect previously synced content.
            guard page.deletions.isEmpty else {
                throw SyncEngineError.configuration("iCloud records were removed outside Lith. Sync paused; local data was kept.")
            }
            let records = try page.modificationResultsByID.values.map {
                try remote($0.get().record)
            }
            let token = try NSKeyedArchiver.archivedData(withRootObject: page.changeToken, requiringSecureCoding: true)
            return SyncChangePage(records: records, token: token, moreComing: page.moreComing)
        } catch { throw mapped(error) }
    }
    public func save(_ record: CloudRecord, revision: Data?) async throws -> SyncRemoteRecord {
        do {
            let existing: CKRecord?
            if let revision {
                let decoder = try NSKeyedUnarchiver(forReadingFrom: revision)
                decoder.requiresSecureCoding = true
                existing = CKRecord(coder: decoder)
                decoder.finishDecoding()
                guard existing != nil else { throw CloudRecordError.invalidRecord }
            } else { existing = nil }
            let value = try CloudKitRecordMapper.encode(record, updating: existing)
            let result = try await database.modifyRecords(saving: [value], deleting: [],
                                                          savePolicy: .ifServerRecordUnchanged, atomically: true)
            guard let saved = result.saveResults[value.recordID] else { throw CloudRecordError.invalidRecord }
            return try remote(saved.get())
        } catch { throw mapped(error) }
    }
    private func remote(_ record: CKRecord) throws -> SyncRemoteRecord {
        let encoder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: encoder)
        encoder.finishEncoding()
        return try SyncRemoteRecord(record: CloudKitRecordMapper.decode(record), revision: encoder.encodedData)
    }
    private func mapped(_ error: Error) -> Error {
        guard let error = error as? CKError else { return error }
        switch error.code {
        case .serverRecordChanged:
            if let record = error.serverRecord, let value = try? remote(record) { return SyncEngineError.serverConflict(value) }
            return error
        case .requestRateLimited, .serviceUnavailable, .zoneBusy, .networkFailure, .networkUnavailable:
            return SyncEngineError.retryable(error.localizedDescription, delay: error.retryAfterSeconds ?? 1)
        case .changeTokenExpired: return SyncEngineError.tokenExpired
        case .notAuthenticated, .accountTemporarilyUnavailable: return SyncEngineError.accountUnavailable
        default: return error
        }
    }
}
#endif

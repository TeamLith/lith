import Foundation
import CryptoKit

/// Natural-key UUIDs exist only at the sync boundary; repositories keep their existing local IDs.
public enum SyncIdentity {
    public static func feed(_ url: URL) -> UUID { stable(["feed", normalized(url)]) }
    public static func item(feedID: UUID, url: URL) -> UUID { stable(["item", feedID.uuidString.lowercased(), normalized(url)]) }
    public static func link(from: UUID, to: UUID, type: LinkType) -> UUID {
        stable(["link", from.uuidString.lowercased(), to.uuidString.lowercased(), type.rawValue])
    }
    private static func normalized(_ url: URL) -> String {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return url.absoluteString }
        parts.scheme = parts.scheme?.lowercased()
        parts.host = parts.host?.lowercased()
        parts.fragment = nil
        return parts.string ?? url.absoluteString
    }
    private static func stable(_ keys: [String]) -> UUID {
        // Length-prefixing prevents delimiter collisions in URLs.
        let bytes = Data(keys.map { "\($0.utf8.count):\($0)" }.joined().utf8)
        var digest = Array(SHA256.hash(data: bytes).prefix(16))
        digest[6] = (digest[6] & 0x0F) | 0x80 // UUID version 8: application-defined deterministic identity.
        digest[8] = (digest[8] & 0x3F) | 0x80
        return UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
                           digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
    }
}

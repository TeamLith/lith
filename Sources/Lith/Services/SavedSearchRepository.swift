import Foundation

public enum SavedSearchError: Error, LocalizedError {
    case invalidName, duplicateName, missingSearch, invalidDates, invalidStore
    public var errorDescription: String? {
        switch self {
        case .invalidName: "Use a name of 1–80 characters without line breaks or control characters."
        case .duplicateName: "A saved search already has that name. Choose another name."
        case .missingSearch: "This saved search is no longer available. Reload the list."
        case .invalidDates: "The start date must be on or before the end date."
        case .invalidStore: "Saved searches could not be read. The existing file has been kept."
        }
    }
}

public protocol SavedSearchRepository: Sendable {
    func all() async throws -> [SavedSearch]
    func save(_ search: SavedSearch) async throws
    func rename(id: UUID, name: String) async throws
    func delete(id: UUID) async throws
}

/// Stores local preferences independently of note data and CloudKit schemas.
public actor LocalSavedSearchRepository: SavedSearchRepository {
    private struct Store: Codable {
        var version = 1
        var searches: [SavedSearch]
    }
    private let url: URL?
    private var memory: [SavedSearch] = []

    /// A nil URL is an isolated, in-memory store for previews and tests.
    public init(url: URL?) { self.url = url }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lith", isDirectory: true).appendingPathComponent("SavedSearches.json")
    }

    public func all() throws -> [SavedSearch] {
        try read().sorted {
            let lhs = $0.name.lowercased(), rhs = $1.name.lowercased()
            return lhs == rhs ? $0.id.uuidString < $1.id.uuidString : lhs < rhs
        }
    }

    public func save(_ search: SavedSearch) throws {
        var searches = try read()
        var value = search
        value.name = try validName(search.name, id: search.id, among: searches)
        searches.removeAll { $0.id == search.id }
        searches.append(value)
        try write(searches)
    }

    public func rename(id: UUID, name: String) throws {
        var searches = try read()
        guard let index = searches.firstIndex(where: { $0.id == id }) else { throw SavedSearchError.missingSearch }
        searches[index].name = try validName(name, id: id, among: searches)
        try write(searches)
    }

    public func delete(id: UUID) throws {
        var searches = try read()
        searches.removeAll { $0.id == id }
        try write(searches)
    }

    private func validName(_ input: String, id: UUID, among searches: [SavedSearch]) throws -> String {
        let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, name.rangeOfCharacter(from: .controlCharacters) == nil else { throw SavedSearchError.invalidName }
        guard !searches.contains(where: { $0.id != id && $0.name.lowercased() == name.lowercased() }) else { throw SavedSearchError.duplicateName }
        return name
    }

    private func read() throws -> [SavedSearch] {
        guard let url else { return memory }
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard let store = try? JSONDecoder().decode(Store.self, from: data), store.version == 1,
              Set(store.searches.map(\.id)).count == store.searches.count else { throw SavedSearchError.invalidStore }
        return store.searches
    }

    private func write(_ searches: [SavedSearch]) throws {
        guard let url else { memory = searches; return }
        let data = try JSONEncoder().encode(Store(searches: searches))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

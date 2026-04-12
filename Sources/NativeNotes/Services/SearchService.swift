import Foundation

public struct SearchService: SearchServiceProtocol, Sendable {
    private let repository: NoteRepository

    public init(repository: NoteRepository) {
        self.repository = repository
    }

    public func search(query: String, filters: SearchFilter) async throws -> [Note] {
        let notes = try await repository.allNotes()
        return notes.filter { note in
            guard filters.sources.contains(note.source) else { return false }
            if !filters.tags.isEmpty && filters.tags.isDisjoint(with: note.tags) { return false }
            if let range = filters.dateRange, !range.contains(note.updatedAt) { return false }
            return query.isEmpty || SearchQueryEvaluator.matches(note: note, query: query)
        }
    }

    public func search(query: String, filter: SearchFilter) async throws -> [Note] {
        try await search(query: query, filters: filter)
    }
}

enum SearchQueryEvaluator {
    static func matches(note: Note, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }

        let upper = q.uppercased()
        if upper.contains(" OR ") {
            return upper
                .components(separatedBy: " OR ")
                .contains { matches(note: note, query: $0) }
        }

        if upper.contains(" AND ") {
            return upper
                .components(separatedBy: " AND ")
                .allSatisfy { matches(note: note, query: $0) }
        }

        if upper.hasPrefix("NOT ") {
            let inner = String(q.dropFirst(4))
            return !matches(note: note, query: inner)
        }

        let haystack = searchableText(for: note)
        return haystack.localizedCaseInsensitiveContains(q)
    }

    private static func searchableText(for note: Note) -> String {
        let tagText = note.tags.joined(separator: " ")
        let metadata = note.metadata.values.joined(separator: " ")
        return [note.title, note.bodyMarkdown, tagText, metadata].joined(separator: " ")
    }
}

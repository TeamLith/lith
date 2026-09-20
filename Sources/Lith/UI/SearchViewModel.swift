import Foundation
import Observation

/// Search inputs are a value so SwiftUI can cancel/restart work when any filter changes.
public struct SearchInput: Hashable, Sendable {
    public var query = ""
    public var source: NoteSource?
    public var tags = ""
    public var restrictDates = false
    public var startDate = Date()
    public var endDate = Date()

    public init() {}
}

@Observable
@MainActor
public final class SearchViewModel {
    public var input = SearchInput()
    public private(set) var results: [Note] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    private let service: SearchServiceProtocol
    private var generation = 0

    public init(service: SearchServiceProtocol) {
        self.service = service
    }

    public func search(calendar: Calendar = .current) async {
        generation += 1
        let requestGeneration = generation
        let request = input
        errorMessage = nil
        results = []
        isLoading = true
        defer {
            if generation == requestGeneration { isLoading = false }
        }

        var range: ClosedRange<Date>?
        if request.restrictDates {
            let start = calendar.startOfDay(for: request.startDate)
            let end = calendar.startOfDay(for: request.endDate)
            guard start <= end,
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: end) else {
                errorMessage = "The start date must be on or before the end date."
                return
            }
            // Include every instant on the selected final day, without including tomorrow.
            range = start...Date(timeIntervalSinceReferenceDate: nextDay.timeIntervalSinceReferenceDate.nextDown)
        }
        let tags = Set(request.tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })
        let filters = SearchFilter(
            sources: request.source.map { [$0] } ?? Set(NoteSource.allCases),
            tags: tags,
            dateRange: range
        )
        do {
            let matches = try await service.search(
                query: request.query.trimmingCharacters(in: .whitespacesAndNewlines), filters: filters
            )
            guard generation == requestGeneration, input == request, !Task.isCancelled else { return }
            results = matches.filter { !$0.isArchived && !$0.isTrashed }.sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        } catch {
            guard generation == requestGeneration, input == request, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    public func clearFilters() {
        input = SearchInput()
    }

    public func snippet(for note: Note) -> String {
        let text = note.bodyMarkdown.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let query = input.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = query.isEmpty ? nil : text.range(of: query, options: .caseInsensitive)
        let start = match.map { text.index($0.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex } ?? text.startIndex
        let end = text.index(start, offsetBy: 180, limitedBy: text.endIndex) ?? text.endIndex
        return (start == text.startIndex ? "" : "…") + String(text[start..<end]) + (end == text.endIndex ? "" : "…")
    }
}

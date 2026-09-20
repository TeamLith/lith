import Foundation

/// Persistable search controls, including inactive date picker values.
public struct SearchInput: Codable, Hashable, Sendable {
    public var query = ""
    public var source: NoteSource?
    public var tags = ""
    public var restrictDates = false
    public var startDate = Date()
    public var endDate = Date()
    public init() {}

    public func filters(calendar: Calendar = .current) throws -> SearchFilter {
        var range: ClosedRange<Date>?
        if restrictDates {
            let start = calendar.startOfDay(for: startDate)
            let end = calendar.startOfDay(for: endDate)
            guard start <= end, let nextDay = calendar.date(byAdding: .day, value: 1, to: end) else {
                throw SavedSearchError.invalidDates
            }
            range = start...Date(timeIntervalSinceReferenceDate: nextDay.timeIntervalSinceReferenceDate.nextDown)
        }
        let tagSet = Set(tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })
        return SearchFilter(sources: source.map { [$0] } ?? Set(NoteSource.allCases), tags: tagSet, dateRange: range)
    }
}

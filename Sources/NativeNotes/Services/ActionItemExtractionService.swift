import Foundation

public struct ActionItemExtractionService: ActionItemExtractionServiceProtocol, Sendable {
    public init() {}

    public func extract(from transcript: String, sourceNoteID: UUID, referenceDate: Date = Date()) -> [ActionItem] {
        transcript
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                guard isActionLine(line) else { return nil }
                return ActionItem(
                    sourceNoteID: sourceNoteID,
                    task: normalizeTask(line),
                    assignee: extractAssignee(from: line),
                    dueDate: extractDueDate(from: line, referenceDate: referenceDate),
                    status: .open
                )
            }
    }

    private func isActionLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        let triggers = ["i will", "we need to", "action item", "todo:", "follow up", "by "]
        return triggers.contains { lower.contains($0) }
    }

    private func normalizeTask(_ line: String) -> String {
        line
            .replacingOccurrences(of: "Action item:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "TODO:", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractAssignee(from line: String) -> String? {
        let tokens = line.split(separator: " ").map(String.init)
        guard tokens.count >= 2 else { return nil }
        let first = tokens[0].lowercased()
        if ["i", "we"].contains(first) { return tokens[0] }
        return nil
    }

    private func extractDueDate(from line: String, referenceDate: Date) -> Date? {
        let lower = line.lowercased()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        if lower.contains("eod"), let date = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: referenceDate) {
            return date
        }
        if lower.contains("in two weeks") {
            return calendar.date(byAdding: .day, value: 14, to: referenceDate)
        }
        if lower.contains("next friday") {
            return nextWeekday(.friday, from: referenceDate, calendar: calendar)
        }
        return nil
    }

    private func nextWeekday(_ weekday: Weekday, from date: Date, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.weekday = weekday.rawValue
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }
}

private enum Weekday: Int {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

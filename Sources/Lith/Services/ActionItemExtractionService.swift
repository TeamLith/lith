import Foundation
import CryptoKit

public struct ActionItemDraft: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let sourceNoteID: UUID
    public let sourceText: String
    public var task: String
    public var assignee: String?
    public var dueDate: Date?

    public init(id: UUID, sourceNoteID: UUID, sourceText: String, task: String, assignee: String? = nil, dueDate: Date? = nil) {
        self.id = id
        self.sourceNoteID = sourceNoteID
        self.sourceText = sourceText
        self.task = task
        self.assignee = assignee
        self.dueDate = dueDate
    }
}

/// Conservative English heuristics. Every suggestion is a draft until accepted.
public struct ActionItemExtractionService: ActionItemExtractionServiceProtocol, Sendable {
    private let calendar: Calendar
    public init(calendar: Calendar = .current) { self.calendar = calendar }

    public func extract(from transcript: String, sourceNoteID: UUID, referenceDate: Date = Date()) -> [ActionItem] {
        drafts(from: transcript, sourceNoteID: sourceNoteID, referenceDate: referenceDate).map {
            ActionItem(id: $0.id, sourceNoteID: $0.sourceNoteID, task: $0.task, assignee: $0.assignee, dueDate: $0.dueDate)
        }
    }

    public func drafts(from transcript: String, sourceNoteID: UUID, referenceDate: Date = Date()) -> [ActionItemDraft] {
        var seen: Set<UUID> = []
        // Spoken transcripts commonly have sentences without line breaks.
        let sentences = transcript.replacingOccurrences(of: #"(?<=[.!?])\s+"#, with: "\n", options: .regularExpression)
            .components(separatedBy: .newlines)
        return sentences.compactMap { sentence in
            let line = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
                .replacingOccurrences(of: #"^[-*•]\s*"#, with: "", options: .regularExpression)
            guard !line.isEmpty, line.range(of: #"(?i)^(?:perhaps|maybe|if|assuming|suppose|hopefully)\b"#, options: .regularExpression) == nil else { return nil }
            let explicit = capture(#"(?i)^(?:todo|action item)\s*:\s*(.+)$"#, in: line)
            let commitment = capture(#"(?i)^(?:i|we)\s+(?:will|need to)\s+(.+)$"#, in: line)
            let named = capture(#"^([A-Z][\p{L}'-]*(?: [A-Z][\p{L}'-]*)?)\s+will\s+(.+)$"#, in: line, group: 2)
            let followUp = line.lowercased().hasPrefix("follow up ")
            guard explicit != nil || commitment != nil || named != nil || followUp else { return nil }
            if explicit == nil, line.range(of: #"(?i)\b(?:will not|won't|need not|do not need to|don't need to)\b"#, options: .regularExpression) != nil { return nil }
            let task = (explicit ?? line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !task.isEmpty else { return nil }
            let key = task.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
            let id = stableID(noteID: sourceNoteID, task: key)
            guard seen.insert(id).inserted else { return nil }
            return ActionItemDraft(id: id, sourceNoteID: sourceNoteID, sourceText: line, task: task,
                                   assignee: assignee(in: task), dueDate: dueDate(in: task, referenceDate: referenceDate))
        }
    }

    private func assignee(in text: String) -> String? {
        if let assigned = capture(#"(?i:\bassigned to)\s+([\p{L}][\p{L}'-]*(?:\s+[A-Z][\p{L}'-]*)?)"#, in: text) { return assigned }
        if let name = capture(#"^([A-Z][\p{L}'-]*(?: [A-Z][\p{L}'-]*)?)\s+(?:will|needs to)\b"#, in: text) { return name }
        return capture(#"(?i)^(i|we)\s+(?:will|need to)\b"#, in: text)
    }

    private func dueDate(in text: String, referenceDate: Date) -> Date? {
        let day = calendar.startOfDay(for: referenceDate)
        if let iso = capture(#"\b(\d{4}-\d{2}-\d{2})\b"#, in: text) {
            let parts = iso.split(separator: "-").compactMap { Int($0) }
            if parts.count == 3, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) {
                let actual = calendar.dateComponents([.year, .month, .day], from: date)
                if actual.year == parts[0], actual.month == parts[1], actual.day == parts[2] { return date }
            }
            return nil
        }
        if text.range(of: #"(?i)\b(?:eod|end of day)\b"#, options: .regularExpression) != nil {
            return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day)
        }
        if text.range(of: #"(?i)\btomorrow\b"#, options: .regularExpression) != nil {
            return calendar.date(byAdding: .day, value: 1, to: day)
        }
        if text.range(of: #"(?i)\btoday\b"#, options: .regularExpression) != nil { return day }
        if let amountText = capture(#"(?i)\bin\s+(\d+|one|two)\s+(?:days?|weeks?)\b"#, in: text),
           let unit = capture(#"(?i)\bin\s+(?:\d+|one|two)\s+(days?|weeks?)\b"#, in: text) {
            let amount = Int(amountText) ?? (amountText.lowercased() == "one" ? 1 : 2)
            guard amount <= 3_650 else { return nil }
            return calendar.date(byAdding: .day, value: amount * (unit.lowercased().hasPrefix("week") ? 7 : 1), to: day)
        }
        if let weekday = capture(#"(?i)\bnext\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b"#, in: text),
           let index = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"].firstIndex(of: weekday.lowercased()) {
            let delta = (index + 1 - calendar.component(.weekday, from: day) + 7) % 7
            return calendar.date(byAdding: .day, value: delta == 0 ? 7 : delta, to: day)
        }
        return nil
    }

    private func capture(_ pattern: String, in text: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }

    private func stableID(noteID: UUID, task: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data((noteID.uuidString.lowercased() + "\n" + task).utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

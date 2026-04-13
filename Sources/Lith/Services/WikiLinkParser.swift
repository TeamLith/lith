import Foundation

public struct WikiLinkParser: Sendable {
    private let pattern = #"\[\[([^\]]+)\]\]"#

    public init() {}

    public func targets(in markdown: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let fullRange = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        var results: [String] = []
        for match in regex.matches(in: markdown, range: fullRange) {
            guard match.numberOfRanges > 1, let groupRange = Range(match.range(at: 1), in: markdown) else {
                continue
            }
            let raw = String(markdown[groupRange])
            let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                results.append(normalized)
            }
        }
        return results
    }

    public func links(for source: Note, allNotes: [Note]) -> [Link] {
        let index = allNotes.reduce(into: [String: UUID]()) { partialResult, note in
            let normalizedTitle = note.title.lowercased()
            if partialResult[normalizedTitle] == nil {
                partialResult[normalizedTitle] = note.id
            }
        }
        var seenTargets: Set<UUID> = []

        return targets(in: source.bodyMarkdown).compactMap { target in
            guard let targetID = index[target.lowercased()], targetID != source.id else {
                return nil
            }
            guard seenTargets.insert(targetID).inserted else {
                return nil
            }
            return Link(fromNoteID: source.id, toNoteID: targetID, type: .wikilink)
        }
    }
}

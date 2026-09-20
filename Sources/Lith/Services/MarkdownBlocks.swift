import Foundation

public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedItem(String)
    case orderedItem(number: String, text: String)
    case quote(String)
    case code(language: String, text: String)
    case rule
}

/// Small block parser with readable fallback. Inline markup is rendered natively.
public struct MarkdownBlockParser: Sendable {
    public init() {}
    public func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String] = []
        var fence: String?
        var language = ""
        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let opening = fence {
                let count = trimmed.prefix(while: { $0 == opening.first! }).count
                if count >= opening.count, trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces).isEmpty {
                    blocks.append(.code(language: language, text: code.joined(separator: "\n")))
                    code = []; fence = nil
                } else { code.append(line) }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flush()
                let marker = String(trimmed.prefix(while: { $0 == trimmed.first! }))
                fence = marker
                language = String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if trimmed.isEmpty { flush(); continue }
            let hashes = trimmed.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), trimmed.dropFirst(hashes).hasPrefix(" ") {
                flush(); blocks.append(.heading(level: hashes, text: String(trimmed.dropFirst(hashes + 1)))); continue
            }
            if ["---", "***", "___"].contains(trimmed) { flush(); blocks.append(.rule); continue }
            if trimmed.hasPrefix("> ") { flush(); blocks.append(.quote(String(trimmed.dropFirst(2)))); continue }
            if ["- ", "* ", "+ "].contains(where: { trimmed.hasPrefix($0) }) {
                flush(); blocks.append(.unorderedItem(String(trimmed.dropFirst(2)))); continue
            }
            let digits = trimmed.prefix(while: \.isNumber)
            let remaining = trimmed.dropFirst(digits.count)
            if !digits.isEmpty, remaining.hasPrefix(". ") || remaining.hasPrefix(") ") {
                flush(); blocks.append(.orderedItem(number: String(digits), text: String(remaining.dropFirst(2)))); continue
            }
            paragraph.append(line)
        }
        if fence != nil { blocks.append(.code(language: language, text: code.joined(separator: "\n"))) }
        flush()
        return blocks
    }
}

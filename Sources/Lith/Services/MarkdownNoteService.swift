import Foundation

public enum MarkdownNoteError: Error, LocalizedError {
    case invalidEncoding
    public var errorDescription: String? { "This file is not valid UTF-8 Markdown." }
}

/// Portable text export: a standard title front matter followed by the exact body.
public struct MarkdownNoteService: Sendable {
    public init() {}

    public func export(title: String, body: String) throws -> Data {
        let titleJSON = String(decoding: try JSONEncoder().encode(title), as: UTF8.self)
        return Data("---\ntitle: \(titleJSON)\n---\n\(body)".utf8)
    }

    public func decode(_ data: Data, filename: String) throws -> (title: String, body: String) {
        guard var text = String(data: data, encoding: .utf8) else { throw MarkdownNoteError.invalidEncoding }
        if text.hasPrefix("\u{feff}") { text.removeFirst() }
        // Accept our minimal front matter only; preserve all unrecognized content.
        if text.hasPrefix("---\n"), let close = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex) {
            let header = String(text[text.index(text.startIndex, offsetBy: 4)..<close.lowerBound])
            if header.hasPrefix("title: "), !header.contains("\n"),
               let title = try? JSONDecoder().decode(String.self, from: Data(header.dropFirst(7).utf8)) {
                return (title, String(text[close.upperBound...]))
            }
        }
        let name = (filename as NSString).deletingPathExtension
        let title = text.components(separatedBy: .newlines).first(where: { $0.hasPrefix("# ") }).map { String($0.dropFirst(2)) }
        return (title ?? (name.isEmpty ? "Imported Note" : name), text)
    }

    /// Imports always allocate a new note. Files can never overwrite an existing ID.
    public func importNote(data: Data, filename: String, repository: NoteRepository, wikiLinkService: WikiLinkServiceProtocol) async throws -> Note {
        let content = try decode(data, filename: filename)
        let note = Note(title: content.title, bodyMarkdown: content.body)
        try await repository.upsert(note)
        try await wikiLinkService.refreshAllLinks()
        return note
    }
}

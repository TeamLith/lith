import Foundation

public struct RSSConversionService: RSSConversionServiceProtocol, Sendable {
    public init() {}

    public func makeNote(from item: RSSItem, feed: RSSFeed, commentary: String?) -> Note {
        var metadata: [String: String] = [
            "sourceURL": item.linkURL.absoluteString,
            "feedTitle": feed.title
        ]
        if let author = item.author { metadata["author"] = author }
        if let category = feed.category { metadata["feedCategory"] = category }
        if let publishedAt = item.publishedAt {
            metadata["publishedAtISO8601"] = ISO8601DateFormatter().string(from: publishedAt)
        }

        let commentText: String
        if let commentary, !commentary.isEmpty {
            commentText = "\n\n## Commentary\n\(commentary)"
        } else {
            commentText = ""
        }

        let body = """
        # \(item.title)

        Source: \(item.linkURL.absoluteString)

        \(item.content)\(commentText)
        """

        var tags: Set<String> = ["rss"]
        if let category = feed.category, !category.isEmpty {
            tags.insert(category.lowercased())
        }

        return Note(
            title: item.title,
            bodyMarkdown: body,
            tags: tags,
            source: .rss,
            metadata: metadata
        )
    }
}

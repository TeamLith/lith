import Foundation
import Testing
@testable import Lith

@Test func wikiLinkParserExtractsTargets() {
    let parser = WikiLinkParser()
    let targets = parser.targets(in: "Read [[SwiftUI]] and [[ CloudKit ]] today")
    #expect(targets == ["SwiftUI", "CloudKit"])
}

@Test func wikiLinkParserBuildsLinksUsingNoteTitles() {
    let parser = WikiLinkParser()
    let a = Note(id: UUID(), title: "A", bodyMarkdown: "See [[B]]")
    let b = Note(id: UUID(), title: "B", bodyMarkdown: "")
    let links = parser.links(for: a, allNotes: [a, b])
    #expect(links.count == 1)
    #expect(links.first?.fromNoteID == a.id)
    #expect(links.first?.toNoteID == b.id)
}

@Test func wikiLinkParserDeduplicatesTargetsAndIgnoresSelfReferences() {
    let parser = WikiLinkParser()
    let a = Note(id: UUID(), title: "A", bodyMarkdown: "See [[B]], [[ B ]], [[A]], and [[Missing]]")
    let b = Note(id: UUID(), title: "B", bodyMarkdown: "")

    let links = parser.links(for: a, allNotes: [a, b])

    #expect(links.count == 1)
    #expect(links.first?.toNoteID == b.id)
}

@Test func searchSupportsAndOrNot() async throws {
    let repo = InMemoryNoteRepository(seed: [
        Note(title: "SwiftUI Guide", bodyMarkdown: "CloudKit and Notes", tags: ["ios"]),
        Note(title: "RSS", bodyMarkdown: "Feed import", tags: ["rss"]),
        Note(title: "Audio", bodyMarkdown: "Transcription", tags: ["audio"])
    ])
    let service = SearchService(repository: repo)

    let andResult = try await service.search(query: "SwiftUI AND CloudKit", filters: SearchFilter())
    #expect(andResult.count == 1)

    let orResult = try await service.search(query: "RSS OR Audio", filters: SearchFilter())
    #expect(orResult.count == 2)

    let notResult = try await service.search(query: "NOT RSS", filters: SearchFilter())
    #expect(notResult.count == 2)
}

@Test func rssConversionProducesCanonicalMetadata() {
    let service = RSSConversionService()
    let feed = RSSFeed(title: "Engineering", feedURL: URL(string: "https://example.com/feed.xml")!, category: "Tech")
    let item = RSSItem(
        feedID: feed.id,
        title: "Swift 6",
        content: "Release notes",
        author: "Apple",
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        linkURL: URL(string: "https://example.com/swift6")!,
        status: .approved
    )

    let note = service.makeNote(from: item, feed: feed, commentary: "Read this")
    #expect(note.source == .rss)
    #expect(note.tags.contains("rss"))
    #expect(note.metadata["sourceURL"] == "https://example.com/swift6")
    #expect(note.bodyMarkdown.contains("## Commentary"))
}

@Test func graphBuilderBuildsLocalNeighborhood() {
    let builder = GraphBuilder()
    let n1 = Note(id: UUID(), title: "A", bodyMarkdown: "")
    let n2 = Note(id: UUID(), title: "B", bodyMarkdown: "")
    let n3 = Note(id: UUID(), title: "C", bodyMarkdown: "")
    let links = [
        Link(fromNoteID: n1.id, toNoteID: n2.id, type: .wikilink),
        Link(fromNoteID: n2.id, toNoteID: n3.id, type: .wikilink)
    ]

    let graph = builder.build(notes: [n1, n2, n3], links: links, mode: .local(center: n1.id, depth: 1))
    #expect(graph.nodes.count == 2)
    #expect(graph.edges.count == 1)
}

@Test func conflictResolverLastWriterWins() {
    let resolver = ConflictResolver()
    let old = Note(title: "A", bodyMarkdown: "v1", updatedAt: Date(timeIntervalSince1970: 10))
    let new = Note(id: old.id, title: "A", bodyMarkdown: "v2", updatedAt: Date(timeIntervalSince1970: 20))

    let result = resolver.resolve(SyncConflict(local: old, remote: new), policy: .lastWriterWins)
    #expect(result.resolved?.bodyMarkdown == "v2")
    #expect(result.requiresManualReview == false)
}

@Test func actionItemExtractionParsesTriggersAndDates() {
    let extractor = ActionItemExtractionService()
    let ref = Date(timeIntervalSince1970: 1_700_000_000)
    let noteID = UUID()
    let transcript = """
    We need to ship the MVP by next Friday.
    TODO: write integration tests in two weeks.
    Random line.
    """

    let items = extractor.extract(from: transcript, sourceNoteID: noteID, referenceDate: ref)
    #expect(items.count == 2)
    #expect(items.allSatisfy { $0.sourceNoteID == noteID })
    #expect(items.allSatisfy { $0.dueDate != nil })
}

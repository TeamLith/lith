import Foundation
import Testing
@testable import Lith

@Test func searchMatchesTitleBodyTagsMetadataAndTranscript() async throws {
    let titleNote = Note(id: UUID(), title: "Project Atlas", bodyMarkdown: "Kickoff", tags: [])
    let bodyNote = Note(id: UUID(), title: "Roadmap", bodyMarkdown: "Core Data migration plan", tags: [])
    let tagsNote = Note(id: UUID(), title: "WWDC", bodyMarkdown: "Session recap", tags: ["swift", "ios"])
    let metadataNote = Note(
        id: UUID(),
        title: "External Source",
        bodyMarkdown: "Reference",
        tags: [],
        metadata: ["sourceURL": "https://example.com/rfc"]
    )
    let transcriptNote = Note(
        id: UUID(),
        title: "Standup",
        bodyMarkdown: "Audio note",
        tags: ["audio"],
        source: .audio,
        metadata: ["transcript": "Budget approval should be complete by Monday."]
    )

    let repository = InMemoryNoteRepository(seed: [titleNote, bodyNote, tagsNote, metadataNote, transcriptNote])
    let service = SearchService(repository: repository)

    let titleResults = try await service.search(query: "atlas", filters: SearchFilter())
    #expect(titleResults.map(\.id).contains(titleNote.id))

    let bodyResults = try await service.search(query: "migration", filters: SearchFilter())
    #expect(bodyResults.map(\.id).contains(bodyNote.id))

    let tagsResults = try await service.search(query: "swift", filters: SearchFilter())
    #expect(tagsResults.map(\.id).contains(tagsNote.id))

    let metadataResults = try await service.search(query: "example.com/rfc", filters: SearchFilter())
    #expect(metadataResults.map(\.id).contains(metadataNote.id))

    let transcriptResults = try await service.search(query: "budget approval", filters: SearchFilter())
    #expect(transcriptResults.map(\.id).contains(transcriptNote.id))
}

@Test func searchAppliesSourceDateAndTagFilters() async throws {
    let jan5 = Date(timeIntervalSince1970: 1_736_035_200)
    let jan15 = Date(timeIntervalSince1970: 1_736_899_200)
    let jan25 = Date(timeIntervalSince1970: 1_737_763_200)

    let manualNote = Note(
        id: UUID(),
        title: "Manual",
        bodyMarkdown: "Manual content",
        tags: ["alpha"],
        updatedAt: jan5,
        source: .manual
    )
    let rssNote = Note(
        id: UUID(),
        title: "RSS",
        bodyMarkdown: "Feed item",
        tags: ["beta"],
        updatedAt: jan15,
        source: .rss
    )
    let audioNote = Note(
        id: UUID(),
        title: "Audio",
        bodyMarkdown: "Transcript note",
        tags: ["alpha"],
        updatedAt: jan25,
        source: .audio
    )

    let repository = InMemoryNoteRepository(seed: [manualNote, rssNote, audioNote])
    let service = SearchService(repository: repository)

    let sourceFiltered = try await service.search(
        query: "",
        filters: SearchFilter(sources: [.rss], tags: [], dateRange: nil)
    )
    #expect(Set(sourceFiltered.map(\.id)) == [rssNote.id])

    let dateFiltered = try await service.search(
        query: "",
        filters: SearchFilter(sources: Set(NoteSource.allCases), tags: [], dateRange: jan15...jan25)
    )
    #expect(Set(dateFiltered.map(\.id)) == [rssNote.id, audioNote.id])

    let tagFiltered = try await service.search(
        query: "",
        filters: SearchFilter(sources: Set(NoteSource.allCases), tags: ["alpha"], dateRange: nil)
    )
    #expect(Set(tagFiltered.map(\.id)) == [manualNote.id, audioNote.id])

    let combined = try await service.search(
        query: "transcript",
        filters: SearchFilter(sources: [.audio], tags: ["alpha"], dateRange: jan15...jan25)
    )
    #expect(Set(combined.map(\.id)) == [audioNote.id])
}

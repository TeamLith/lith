#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

public enum AppBootstrapMode: Sendable {
    case live
    case inMemory
}

@available(macOS 10.15, iOS 13.0, *)
public final class AppDependencyContainer: @unchecked Sendable {
    public let persistentContainer: NSPersistentContainer
    public let noteRepository: NoteRepository
    public let linkRepository: LinkRepository
    @MainActor public lazy var audioServices = AudioServices(repository: audioRecordingRepository)
    public let audioRecordingRepository: AudioRecordingRepository
    public let rssRepository: RSSRepository
    public let savedSearchRepository: SavedSearchRepository
    public let searchService: SearchServiceProtocol
    public let rssConversionService: RSSConversionServiceProtocol
    public let rssFetchService: RSSFetchServiceProtocol
    @MainActor public lazy var actionReviewService = ActionItemReviewService(repository: actionItemRepository, notes: noteRepository)
    public let actionItemRepository: ActionItemRepository
    public let actionItemExtractionService: ActionItemExtractionServiceProtocol
    public let wikiLinkService: WikiLinkServiceProtocol

    public func transcript(for noteID: UUID) async throws -> String {
        try await audioRecordingRepository.recordings(noteID: noteID).compactMap(\.transcript).joined(separator: "\n\n")
    }

    public init(mode: AppBootstrapMode = .live) throws {
        let persistentContainer = try LithPersistentStore.makeContainer(inMemory: mode == .inMemory)
        self.persistentContainer = persistentContainer

        let noteRepository = CoreDataNoteRepository(container: persistentContainer)
        let linkRepository = CoreDataLinkRepository(container: persistentContainer)
        let rssRepository = CoreDataRSSRepository(container: persistentContainer)

        self.audioRecordingRepository = CoreDataAudioRecordingRepository(container: persistentContainer)
        self.noteRepository = noteRepository
        self.linkRepository = linkRepository
        self.rssRepository = rssRepository
        self.savedSearchRepository = LocalSavedSearchRepository(url: mode == .inMemory ? nil : LocalSavedSearchRepository.defaultURL)
        self.searchService = SearchService(repository: noteRepository)
        self.rssConversionService = RSSConversionService()
        self.rssFetchService = RSSFetchService(repository: rssRepository)
        self.actionItemRepository = CoreDataActionItemRepository(container: persistentContainer)
        self.actionItemExtractionService = ActionItemExtractionService()
        self.wikiLinkService = WikiLinkService(noteRepository: noteRepository, linkRepository: linkRepository)
    }
}
#endif

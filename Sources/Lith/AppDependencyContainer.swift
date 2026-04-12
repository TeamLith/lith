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
    public let rssRepository: RSSRepository
    public let searchService: SearchServiceProtocol
    public let rssConversionService: RSSConversionServiceProtocol
    public let actionItemExtractionService: ActionItemExtractionServiceProtocol

    public init(mode: AppBootstrapMode = .live) throws {
        let persistentContainer = try LithPersistentStore.makeContainer(inMemory: mode == .inMemory)
        self.persistentContainer = persistentContainer

        let noteRepository = CoreDataNoteRepository(container: persistentContainer)
        let rssRepository = CoreDataRSSRepository(container: persistentContainer)

        self.noteRepository = noteRepository
        self.rssRepository = rssRepository
        self.searchService = SearchService(repository: noteRepository)
        self.rssConversionService = RSSConversionService()
        self.actionItemExtractionService = ActionItemExtractionService()
    }
}
#endif

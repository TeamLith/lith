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
    public let rssRepository: RSSRepository
    public let searchService: SearchServiceProtocol
    public let rssConversionService: RSSConversionServiceProtocol
    public let rssFetchService: RSSFetchServiceProtocol
    public let actionItemExtractionService: ActionItemExtractionServiceProtocol
    public let wikiLinkService: WikiLinkServiceProtocol
    private let bootstrapMode: AppBootstrapMode

    @available(iOS 17, macOS 14, *)
    @MainActor public lazy var syncSettings: SyncSettingsViewModel = makeSyncSettings()

    @available(iOS 17, macOS 14, *)
    @MainActor private func makeSyncSettings() -> SyncSettingsViewModel {
        guard bootstrapMode == .live else {
            return SyncSettingsViewModel(engine: nil, preferences: MemorySyncPreferences(),
                                         unavailableReason: "Preview uses local, in-memory data.")
        }
        let preferences = UserDefaultsSyncPreferences()
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "LithCloudKitContainerIdentifier") as? String,
              !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SyncSettingsViewModel(engine: nil, preferences: preferences,
                                         unavailableReason: "iCloud is unavailable in this build. A release owner must configure its iCloud container.")
        }
        do {
            let transport = try AppleCloudKitTransport(containerIdentifier: identifier)
            let stateURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Lith/Sync/checkpoint.json")
            let engine = SyncEngine(transport: transport, local: CoreDataSyncStore(container: persistentContainer),
                                    persistence: FileSyncStatePersistence(url: stateURL))
            return SyncSettingsViewModel(engine: engine, preferences: preferences)
        } catch {
            return SyncSettingsViewModel(engine: nil, preferences: preferences, unavailableReason: error.localizedDescription)
        }
    }

    public init(mode: AppBootstrapMode = .live) throws {
        self.bootstrapMode = mode
        let persistentContainer = try LithPersistentStore.makeContainer(inMemory: mode == .inMemory)
        self.persistentContainer = persistentContainer

        let noteRepository = CoreDataNoteRepository(container: persistentContainer)
        let linkRepository = CoreDataLinkRepository(container: persistentContainer)
        let rssRepository = CoreDataRSSRepository(container: persistentContainer)

        self.noteRepository = noteRepository
        self.linkRepository = linkRepository
        self.rssRepository = rssRepository
        self.searchService = SearchService(repository: noteRepository)
        self.rssConversionService = RSSConversionService()
        self.rssFetchService = RSSFetchService(repository: rssRepository)
        self.actionItemExtractionService = ActionItemExtractionService()
        self.wikiLinkService = WikiLinkService(noteRepository: noteRepository, linkRepository: linkRepository)
    }
}
#endif

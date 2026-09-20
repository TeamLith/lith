import SwiftUI
import Lith

private enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case notes
    case rss
    case search
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .notes:
            return "Notes"
        case .rss:
            return "RSS Inbox"
        case .search:
            return "Search & Graph"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .notes:
            return "note.text"
        case .rss:
            return "dot.radiowaves.left.and.right"
        case .search:
            return "magnifyingglass.circle"
        case .settings:
            return "gearshape"
        }
    }

    var headline: String {
        switch self {
        case .notes:
            return "Text notes land here first."
        case .rss:
            return "Review feeds before turning them into notes."
        case .search:
            return "Search and graph navigation share one discovery surface."
        case .settings:
            return "Local-first defaults and sync controls live here."
        }
    }

    var summary: String {
        switch self {
        case .notes:
            return "Pinned and recent note sections will replace this placeholder in the next UI task."
        case .rss:
            return "Add feeds, review articles, and approve the ones you want to save as notes."
        case .search:
            return "Query filters and graph exploration will connect once the dedicated UI tasks land."
        case .settings:
            return "Control optional iCloud sync, check progress, and review retained conflicts."
        }
    }
}

struct RootView: View {
    private let dependencies: AppDependencyContainer

    @Environment(\.scenePhase) private var scenePhase
    @State private var syncSceneID = UUID()
    @State private var selectedSection: AppSection? = .notes
    @State private var noteListViewModel: NoteListViewModel
    @State private var rssInboxViewModel: RSSInboxViewModel

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        self._noteListViewModel = State(initialValue: NoteListViewModel(repository: dependencies.noteRepository, wikiLinkService: dependencies.wikiLinkService))
        self._rssInboxViewModel = State(
            initialValue: RSSInboxViewModel(
                repository: dependencies.rssRepository,
                noteRepository: dependencies.noteRepository,
                fetchService: dependencies.rssFetchService,
                wikiLinkService: dependencies.wikiLinkService
            )
        )
    }

    var body: some View {
        platformBody
            .task {
                await dependencies.syncSettings.restoreStatus()
                dependencies.syncSettings.setSceneActive(syncSceneID, active: scenePhase == .active)
            }
            .onChange(of: scenePhase) { _, phase in
                dependencies.syncSettings.setSceneActive(syncSceneID, active: phase == .active)
            }
            .onDisappear { dependencies.syncSettings.setSceneActive(syncSceneID, active: false) }
    }

    private var platformBody: some View {
#if os(macOS)
        macOSBody
#else
        TabView {
            ForEach(AppSection.allCases) { section in
                NavigationStack {
                    ShellDetailView(
                        section: section,
                        dependencies: dependencies,
                        noteListViewModel: noteListViewModel,
                        rssInboxViewModel: rssInboxViewModel
                    )
                }
                .tabItem {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
        }
#endif
    }

#if os(macOS)
    @State private var selectedNoteID: UUID?

    private var macOSBody: some View {
        Group {
            if selectedSection == .notes {
                NavigationSplitView {
                    appSidebar
                } content: {
                    NoteListView(
                        repository: dependencies.noteRepository,
                        wikiLinkService: dependencies.wikiLinkService,
                        viewModel: noteListViewModel,
                        actionItemRepository: dependencies.actionItemRepository, actionReviewService: dependencies.actionReviewService, transcriptProvider: { try await dependencies.transcript(for: $0) }, audioServices: dependencies.audioServices,
                        selectedNoteID: $selectedNoteID
                    )
                    .navigationSplitViewColumnWidth(min: 240, ideal: 300)
                } detail: {
                    if let selectedNoteID {
                        NoteDetailView(
                            repository: dependencies.noteRepository,
                            wikiLinkService: dependencies.wikiLinkService,
                            noteID: selectedNoteID,
                            actionItemRepository: dependencies.actionItemRepository, actionReviewService: dependencies.actionReviewService, transcriptProvider: { try await dependencies.transcript(for: $0) }, audioServices: dependencies.audioServices
                        ) {
                            await noteListViewModel.loadNotes()
                        }
                        .id(selectedNoteID)
                    } else {
                        ContentUnavailableView(
                            "No Note Selected",
                            systemImage: "note.text",
                            description: Text("Select a note from the list to read or edit it.")
                        )
                    }
                }
            } else {
                NavigationSplitView {
                    appSidebar
                } detail: {
                    ShellDetailView(
                        section: selectedSection ?? .notes,
                        dependencies: dependencies,
                        noteListViewModel: noteListViewModel,
                        rssInboxViewModel: rssInboxViewModel
                    )
                }
            }
        }
    }

    private var appSidebar: some View {
        List(AppSection.allCases, selection: $selectedSection) { section in
            Label(section.title, systemImage: section.systemImage)
                .accessibilityIdentifier("navigation-\(section.rawValue)")
                .tag(section)
        }
        .navigationTitle("Lith")
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }
#endif
}

private struct ShellDetailView: View {
    let section: AppSection
    let dependencies: AppDependencyContainer
    let noteListViewModel: NoteListViewModel
    let rssInboxViewModel: RSSInboxViewModel

    var body: some View {
#if os(iOS)
        if section == .notes {
            NoteListView(
                repository: dependencies.noteRepository,
                wikiLinkService: dependencies.wikiLinkService,
                viewModel: noteListViewModel,
                actionItemRepository: dependencies.actionItemRepository, actionReviewService: dependencies.actionReviewService, transcriptProvider: { try await dependencies.transcript(for: $0) }, audioServices: dependencies.audioServices
            )
        } else if section == .search {
            SearchView(dependencies: dependencies)
        } else if section == .rss {
            RSSInboxView(viewModel: rssInboxViewModel, dependencies: dependencies) {
                await noteListViewModel.loadNotes()
            }
        } else if section == .settings {
            SyncSettingsView(viewModel: dependencies.syncSettings)
        } else {
            placeholderBody
        }
#else
        if section == .search {
            NavigationStack { SearchView(dependencies: dependencies) }
        } else if section == .rss {
            RSSInboxView(viewModel: rssInboxViewModel, dependencies: dependencies) {
                await noteListViewModel.loadNotes()
            }
        } else if section == .settings {
            SyncSettingsView(viewModel: dependencies.syncSettings)
        } else {
            placeholderBody
        }
#endif
    }

    private var placeholderBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(section.title, systemImage: section.systemImage)
                        .font(.largeTitle.weight(.semibold))

                    Text(section.headline)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                ContentUnavailableView {
                    Label(section.title, systemImage: section.systemImage)
                } description: {
                    Text(section.summary)
                } actions: {
                    VStack(alignment: .leading, spacing: 12) {
                        statusRow(label: "Persistence", value: dependencies.persistentContainer.name)
                        statusRow(label: "Default note source", value: NoteSource.manual.rawValue.capitalized)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 280)

                sectionFootnote
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(section.title)
    }

    @ViewBuilder
    private func statusRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.weight(.medium))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sectionFootnote: some View {
        Text("This shell keeps the remaining sections intentionally lightweight while dedicated follow-up tasks fill in the full workflows.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

#if DEBUG
@MainActor
private func makePreviewDependencies() -> AppDependencyContainer {
    do {
        return try AppDependencyContainer(mode: .inMemory)
    } catch {
        preconditionFailure("Failed to initialize preview AppDependencyContainer in .inMemory mode: \(error)")
    }
}

@MainActor
private let previewDependencies = makePreviewDependencies()

#if os(iOS)
#Preview("iOS Shell") {
    RootView(dependencies: previewDependencies)
}
#endif

#if os(macOS)
#Preview("macOS Shell") {
    RootView(dependencies: previewDependencies)
        .frame(width: 1100, height: 700)
}
#endif
#endif

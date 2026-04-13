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
            return "Manual feed refresh is available here while inbox grouping and approve-to-save land in the next RSS UI task."
        case .search:
            return "Query filters and graph exploration will connect once the dedicated UI tasks land."
        case .settings:
            return "Sync status, app preferences, and diagnostics will be surfaced in a later task."
        }
    }
}

struct RootView: View {
    private let dependencies: AppDependencyContainer

    @State private var selectedSection: AppSection? = .notes
    @State private var noteListViewModel: NoteListViewModel
    @State private var rssRefreshViewModel: RSSRefreshViewModel

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        self._noteListViewModel = State(initialValue: NoteListViewModel(repository: dependencies.noteRepository))
        self._rssRefreshViewModel = State(
            initialValue: RSSRefreshViewModel(
                repository: dependencies.rssRepository,
                fetchService: dependencies.rssFetchService
            )
        )
    }

    var body: some View {
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
                        rssRefreshViewModel: rssRefreshViewModel
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
                        selectedNoteID: $selectedNoteID
                    )
                    .navigationSplitViewColumnWidth(min: 240, ideal: 300)
                } detail: {
                    if let selectedNoteID {
                        NoteDetailView(
                            repository: dependencies.noteRepository,
                            wikiLinkService: dependencies.wikiLinkService,
                            noteID: selectedNoteID
                        ) {
                            await noteListViewModel.loadNotes()
                        }
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
                        rssRefreshViewModel: rssRefreshViewModel
                    )
                }
            }
        }
    }

    private var appSidebar: some View {
        List(AppSection.allCases, selection: $selectedSection) { section in
            Label(section.title, systemImage: section.systemImage)
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
    let rssRefreshViewModel: RSSRefreshViewModel

    var body: some View {
#if os(iOS)
        if section == .notes {
            NoteListView(
                repository: dependencies.noteRepository,
                wikiLinkService: dependencies.wikiLinkService,
                viewModel: noteListViewModel
            )
        } else if section == .rss {
            RSSRefreshPanel(viewModel: rssRefreshViewModel)
        } else {
            placeholderBody
        }
#else
        if section == .rss {
            RSSRefreshPanel(viewModel: rssRefreshViewModel)
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

@available(iOS 17, macOS 14, *)
private struct RSSRefreshPanel: View {
    @Bindable var viewModel: RSSRefreshViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.feeds.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError {
                ContentUnavailableView {
                    Label("Could Not Load RSS Feeds", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Retry") { Task { await viewModel.loadFeeds() } }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("RSS Inbox", systemImage: "dot.radiowaves.left.and.right")
                                .font(.largeTitle.weight(.semibold))

                            Text("Manual refresh is wired now; grouping and approve-to-save still belong to the follow-up inbox UI issue.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        refreshSummary

                        if viewModel.feeds.isEmpty {
                            ContentUnavailableView(
                                "No RSS Feeds Yet",
                                systemImage: "dot.radiowaves.left.and.right",
                                description: Text("Once feeds are configured, use Refresh Feeds to fetch and store the latest items.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            feedList
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("RSS Inbox")
        .task {
            guard viewModel.feeds.isEmpty, viewModel.loadError == nil else {
                return
            }

            await viewModel.loadFeeds()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refreshFeeds() }
                } label: {
                    if viewModel.isRefreshing {
                        Label("Refreshing", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    } else {
                        Label("Refresh Feeds", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRefreshing)
            }
        }
    }

    private var refreshSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                summaryCard(
                    label: "Configured feeds",
                    value: "\(viewModel.feeds.count)"
                )
                summaryCard(
                    label: "Active feeds",
                    value: "\(viewModel.feeds.filter(\.isActive).count)"
                )
                summaryCard(
                    label: "Last refresh",
                    value: lastRefreshLabel
                )
            }

            if let report = viewModel.lastRefreshReport {
                Text("\(report.refreshedFeedCount) feeds refreshed, \(report.processedItemCount) items processed.")
                    .font(.subheadline.weight(.medium))

                if !report.failures.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failures")
                            .font(.headline)

                        ForEach(report.failures) { failure in
                            Text("\(failure.feedTitle): \(failure.error?.localizedDescription ?? "Unknown error")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Refresh feeds to fetch updates for all active sources.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var feedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configured Feeds")
                .font(.headline)

            ForEach(viewModel.feeds) { feed in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(feed.title)
                            .font(.headline)

                        Spacer()

                        Text(feed.isActive ? "Active" : "Paused")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(feed.isActive ? Color.green.opacity(0.14) : Color.secondary.opacity(0.12), in: Capsule())
                    }

                    Text(feed.feedURL.absoluteString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        if let category = feed.category, !category.isEmpty {
                            Label(category, systemImage: "tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let lastFetchedAt = feed.lastFetchedAt {
                            Label {
                                Text(lastFetchedAt, style: .relative)
                            } icon: {
                                Image(systemName: "clock")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            Label("Never refreshed", systemImage: "clock.badge.questionmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var lastRefreshLabel: String {
        guard let completedAt = viewModel.lastRefreshReport?.completedAt else {
            return "Not yet"
        }

        return completedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func summaryCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

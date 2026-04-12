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
            return "Feed refresh, grouping, and approve-to-save workflows are not wired yet."
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

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
    }

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Lith")
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            ShellDetailView(
                section: selectedSection ?? .notes,
                dependencies: dependencies
            )
        }
#else
        TabView {
            ForEach(AppSection.allCases) { section in
                NavigationStack {
                    ShellDetailView(section: section, dependencies: dependencies)
                }
                .tabItem {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
        }
#endif
    }
}

private struct ShellDetailView: View {
    let section: AppSection
    let dependencies: AppDependencyContainer

    var body: some View {
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
        Text("This shell intentionally stops at navigation and empty states so the follow-up tasks can own notes, RSS, search, and settings behavior.")
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

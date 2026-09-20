import SwiftUI
import Lith

struct RSSInboxView: View {
    @Bindable var viewModel: RSSInboxViewModel
    let dependencies: AppDependencyContainer
    let onNoteChanged: @MainActor () async -> Void
    @State private var addingFeed = false
    @State private var selectedItem: RSSItem?

    var body: some View {
        List {
            Section {
                Picker("Show articles", selection: $viewModel.statusFilter) {
                    Text("All").tag(Optional<RSSItemStatus>.none)
                    Text("New").tag(Optional(RSSItemStatus.new))
                    Text("Approved").tag(Optional(RSSItemStatus.approved))
                    Text("Ignored").tag(Optional(RSSItemStatus.ignored))
                    Text("Saved").tag(Optional(RSSItemStatus.savedAsNote))
                }
                if viewModel.isBusy { ProgressView("Updating inbox…") }
                if let error = viewModel.error {
                    Text(error.localizedDescription).foregroundStyle(.red)
                    Button("Reload Inbox") { Task { await viewModel.load() } }
                }
                if let report = viewModel.lastRefreshReport {
                    Text("\(report.refreshedFeedCount) feeds refreshed · \(report.processedItemCount) articles processed")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(report.failures) { failure in
                        Text("\(failure.feedTitle): \(failure.error?.localizedDescription ?? "Refresh failed")")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            }
            if viewModel.feeds.isEmpty {
                ContentUnavailableView("No RSS Feeds", systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Add a feed URL, then refresh to review its articles."))
            }
            ForEach(viewModel.groups) { group in
                Section(group.title) {
                    if group.items.isEmpty {
                        Text("No matching articles. Refresh or choose another filter.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(group.items) { item in
                        Button { selectedItem = item } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title).font(.headline).foregroundStyle(.primary)
                                HStack {
                                    Text(item.status.displayTitle)
                                    if let date = item.publishedAt { Text(date, style: .date) }
                                }.font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("RSS Inbox")
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { Task { await viewModel.refresh() } } label: {
                    Label("Refresh Feeds", systemImage: "arrow.clockwise")
                }.disabled(viewModel.isBusy || viewModel.feeds.isEmpty)
                Button { addingFeed = true } label: { Label("Add Feed", systemImage: "plus") }
                    .disabled(viewModel.isBusy)
            }
        }
        .sheet(isPresented: $addingFeed) { AddRSSFeedView(viewModel: viewModel) }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                RSSArticleView(itemID: item.id, viewModel: viewModel,
                               dependencies: dependencies, onNoteChanged: onNoteChanged)
            }
            .frame(minWidth: 320, minHeight: 440)
        }
    }
}

private struct AddRSSFeedView: View {
    @Bindable var viewModel: RSSInboxViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var title = ""
    @State private var category = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Feed URL (https://…)", text: $url)
#if os(iOS)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
#endif
                TextField("Title (optional)", text: $title)
                TextField("Category (optional)", text: $category)
                Text("Articles stay in your inbox until you approve and save them.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = viewModel.error { Text(error.localizedDescription).foregroundStyle(.red) }
            }
            .navigationTitle("Add RSS Feed")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            if await viewModel.addFeed(url: url, title: title, category: category) { dismiss() }
                        }
                    }.disabled(viewModel.isBusy || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 300)
    }
}

private struct RSSArticleView: View {
    let itemID: UUID
    @Bindable var viewModel: RSSInboxViewModel
    let dependencies: AppDependencyContainer
    let onNoteChanged: @MainActor () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var commentary = ""
    @State private var savedNoteID: UUID?

    private var item: RSSItem? { viewModel.items.first { $0.id == itemID } }

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: 18) {
                    Text(item.title).font(.title)
                    Text(item.status.displayTitle).font(.subheadline).foregroundStyle(.secondary)
                    if let author = item.author { Text(author).foregroundStyle(.secondary) }
                    if let date = item.publishedAt { Text(date, style: .date).foregroundStyle(.secondary) }
                    SwiftUI.Link("Read Original Article", destination: item.linkURL)
                    Text(item.content).textSelection(.enabled)
                    if item.status == .savedAsNote, let noteID = item.savedNoteID {
                        Button("Open Saved Note") { savedNoteID = noteID }
                    } else if item.status == .approved {
                        TextField("Optional commentary", text: $commentary, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        Button("Save as Note") {
                            Task {
                                if let noteID = await viewModel.saveAsNote(itemID: item.id, commentary: commentary) {
                                    await onNoteChanged()
                                    savedNoteID = noteID
                                }
                            }
                        }.buttonStyle(.borderedProminent)
                    } else {
                        Button("Approve") { Task { await viewModel.setStatus(.approved, itemID: item.id) } }
                            .buttonStyle(.borderedProminent)
                    }
                    if item.status != .savedAsNote {
                        HStack {
                            if item.status != .ignored {
                                Button("Ignore") { Task { await viewModel.setStatus(.ignored, itemID: item.id) } }
                            }
                            if item.status != .new {
                                Button("Mark New") { Task { await viewModel.setStatus(.new, itemID: item.id) } }
                            }
                        }
                    }
                    if let error = viewModel.error { Text(error.localizedDescription).foregroundStyle(.red) }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(viewModel.isBusy)
            } else {
                ContentUnavailableView("Article Unavailable", systemImage: "doc.questionmark")
            }
        }
        .navigationTitle("Review Article")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .sheet(isPresented: Binding(get: { savedNoteID != nil }, set: { if !$0 { savedNoteID = nil } })) {
            if let savedNoteID {
                NavigationStack {
                    NoteDetailView(repository: dependencies.noteRepository,
                                   wikiLinkService: dependencies.wikiLinkService,
                                   noteID: savedNoteID, onNoteChanged: onNoteChanged)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { self.savedNoteID = nil }
                        }
                    }
                }.frame(minWidth: 320, minHeight: 440)
            }
        }
    }
}

private extension RSSItemStatus {
    var displayTitle: String {
        switch self {
        case .new: "New"
        case .approved: "Approved"
        case .ignored: "Ignored"
        case .savedAsNote: "Saved as Note"
        }
    }
}

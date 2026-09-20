import SwiftUI
import Observation
import UniformTypeIdentifiers
import Lith

/// Note list screen showing pinned and recent note sections.
///
/// On macOS, note selection is communicated via the `selectedNote` binding so
/// that `RootView` can render the detail in the third split-view column.
/// On iOS the view relies on the `NavigationStack` already provided by `RootView`
/// and pushes `NoteDetailView` via `NavigationLink`.
@available(iOS 17, macOS 14, *)
struct NoteListView: View {
    let repository: NoteRepository
    let wikiLinkService: WikiLinkServiceProtocol
    @Bindable var viewModel: NoteListViewModel
    @State private var importing = false
    @State private var importError: String?
    @State private var pendingDeletion: Note?

#if os(macOS)
    @Binding var selectedNoteID: UUID?

    init(
        repository: NoteRepository,
        wikiLinkService: WikiLinkServiceProtocol,
        viewModel: NoteListViewModel,
        selectedNoteID: Binding<UUID?>
    ) {
        self.repository = repository
        self.wikiLinkService = wikiLinkService
        self.viewModel = viewModel
        self._selectedNoteID = selectedNoteID
    }
#else
    init(repository: NoteRepository, wikiLinkService: WikiLinkServiceProtocol, viewModel: NoteListViewModel) {
        self.repository = repository
        self.wikiLinkService = wikiLinkService
        self.viewModel = viewModel
    }
#endif

    var body: some View {
        VStack(spacing: 0) {
            Picker("Collection", selection: $viewModel.collection) {
                ForEach(NoteCollection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).padding()
            noteListContent
        }
            .navigationTitle(viewModel.collection.rawValue)
            .task(id: viewModel.collection) { await viewModel.loadNotes() }
            .fileImporter(isPresented: $importing, allowedContentTypes: MarkdownFile.readableContentTypes) { result in
                Task {
                    do {
                        let url = try result.get()
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        let imported = await viewModel.importMarkdown(data: data, filename: url.lastPathComponent, wikiLinkService: wikiLinkService)
#if os(macOS)
                        if let imported { selectedNoteID = imported.id }
#endif
                    } catch { importError = error.localizedDescription }
                }
            }
            .alert("Could Not Import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK") { importError = nil }
            } message: { Text(importError ?? "") }
            .confirmationDialog("Delete this note permanently?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
                Button("Delete Permanently", role: .destructive) {
                    if let id = pendingDeletion?.id { Task { await delete(noteID: id) } }
                    pendingDeletion = nil
                }
            } message: { Text("This removes \(pendingDeletion?.title.isEmpty == false ? pendingDeletion!.title : "this note") from Lith and cannot be undone.") }
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button { importing = true } label: { Label("Import Markdown", systemImage: "square.and.arrow.down") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            guard let note = await viewModel.createNote() else {
                                return
                            }
#if os(macOS)
                            selectedNoteID = note.id
#endif
                        }
                    } label: {
                        Label("New Note", systemImage: "plus")
                    }
                }
            }
    }

    // MARK: - List content

    @ViewBuilder
    private var noteListContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.loadError {
            ContentUnavailableView {
                Label("Could Not Load Notes", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Retry") { Task { await viewModel.loadNotes() } }
            }
        } else if viewModel.pinnedNotes.isEmpty && viewModel.recentNotes.isEmpty {
            emptyNotesView
        } else {
            noteList
        }
    }

    private var emptyNotesView: some View {
        ContentUnavailableView(
            viewModel.collection == .active ? "No Notes Yet" : "\(viewModel.collection.rawValue) Is Empty",
            systemImage: "note.text.badge.plus",
            description: Text(viewModel.collection == .active ? "Create a note or import a Markdown file to get started." : "Notes in this collection will appear here.")
        )
    }

    private var noteList: some View {
        List {
            if !viewModel.pinnedNotes.isEmpty {
                Section("Pinned") {
                    ForEach(viewModel.pinnedNotes) { note in
                        noteRow(for: note)
                    }
                }
            }

            if !viewModel.recentNotes.isEmpty {
                Section("Recent") {
                    ForEach(viewModel.recentNotes) { note in
                        noteRow(for: note)
                    }
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.loadNotes() }
#endif
    }

    @ViewBuilder
    private func noteRow(for note: Note) -> some View {
#if os(macOS)
        noteRowContent(for: note)
            .contentShape(Rectangle())
            .onTapGesture { selectedNoteID = note.id }
            .background(selectedNoteID == note.id ? Color.accentColor.opacity(0.12) : Color.clear)
            .contextMenu { noteActions(for: note) }
#else
        NavigationLink {
            NoteDetailView(repository: repository, wikiLinkService: wikiLinkService, noteID: note.id) {
                await viewModel.loadNotes()
            }
        } label: {
            noteRowContent(for: note)
        }
        .contextMenu { noteActions(for: note) }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if note.isArchived || note.isTrashed {
                Button("Restore") { Task { await restore(noteID: note.id) } }.tint(.green)
            } else {
                Button("Archive") { Task { await archive(noteID: note.id) } }.tint(.blue)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if note.isTrashed {
                Button("Delete", role: .destructive) { pendingDeletion = note }
            } else {
                Button("Trash", role: .destructive) { Task { await moveToTrash(noteID: note.id) } }
            }
        }
#endif
    }

    private func noteRowContent(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.headline)
                    .lineLimit(1)

                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if !note.bodyMarkdown.isEmpty {
                Text(note.bodyMarkdown)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func noteActions(for note: Note) -> some View {
        if note.isArchived || note.isTrashed {
            Button { Task { await restore(noteID: note.id) } } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
        } else {
            Button { Task { await archive(noteID: note.id) } } label: { Label("Archive", systemImage: "archivebox") }
        }
        if note.isTrashed {
            Button(role: .destructive) { pendingDeletion = note } label: { Label("Delete Permanently", systemImage: "xmark.bin") }
        } else {
            Button(role: .destructive) { Task { await moveToTrash(noteID: note.id) } } label: { Label("Move to Trash", systemImage: "trash") }
        }
    }

    private func restore(noteID: UUID) async {
        await viewModel.restore(noteID: noteID)
#if os(macOS)
        if selectedNoteID == noteID { selectedNoteID = nil }
#endif
    }

    private func archive(noteID: UUID) async {
        await viewModel.archive(noteID: noteID)
#if os(macOS)
        if selectedNoteID == noteID {
            selectedNoteID = nil
        }
#endif
    }

    private func moveToTrash(noteID: UUID) async {
        await viewModel.moveToTrash(noteID: noteID)
#if os(macOS)
        if selectedNoteID == noteID {
            selectedNoteID = nil
        }
#endif
    }

    private func delete(noteID: UUID) async {
        await viewModel.delete(noteID: noteID)
#if os(macOS)
        if selectedNoteID == noteID {
            selectedNoteID = nil
        }
#endif
    }
}

// MARK: - Previews

#if DEBUG
@MainActor
private func makeInMemoryDependencies(notes: [Note] = []) -> (repository: InMemoryNoteRepository, wikiLinkService: WikiLinkService) {
    let repository = InMemoryNoteRepository(seed: notes)
    let linkRepository = InMemoryLinkRepository()
    let wikiLinkService = WikiLinkService(noteRepository: repository, linkRepository: linkRepository)
    return (repository, wikiLinkService)
}

private let sampleNotes: [Note] = [
    Note(
        id: UUID(),
        title: "SwiftUI Architecture",
        bodyMarkdown: "Notes on the MVVM pattern and Observation framework.",
        updatedAt: Date(),
        isPinned: true
    ),
    Note(
        id: UUID(),
        title: "Weekly Review",
        bodyMarkdown: "## Goals\n- Ship note list UI\n- Fix layout bugs",
        updatedAt: Date().addingTimeInterval(-3600)
    ),
    Note(
        id: UUID(),
        title: "Reading List",
        bodyMarkdown: "Books to read this month.",
        updatedAt: Date().addingTimeInterval(-7200)
    ),
]

#if os(iOS)
@available(iOS 17, macOS 14, *)
#Preview("Populated notes list (iOS)") {
    let dependencies = makeInMemoryDependencies(notes: sampleNotes)
    NavigationStack {
        NoteListView(
            repository: dependencies.repository,
            wikiLinkService: dependencies.wikiLinkService,
            viewModel: NoteListViewModel(repository: dependencies.repository)
        )
    }
}

@available(iOS 17, macOS 14, *)
#Preview("Empty notes list (iOS)") {
    let dependencies = makeInMemoryDependencies()
    NavigationStack {
        NoteListView(
            repository: dependencies.repository,
            wikiLinkService: dependencies.wikiLinkService,
            viewModel: NoteListViewModel(repository: dependencies.repository)
        )
    }
}
#endif

#if os(macOS)
@available(iOS 17, macOS 14, *)
#Preview("Populated notes list (macOS)") {
    @Previewable @State var selectedNoteID: UUID? = nil
    let dependencies = makeInMemoryDependencies(notes: sampleNotes)
    NavigationSplitView {
        NoteListView(
            repository: dependencies.repository,
            wikiLinkService: dependencies.wikiLinkService,
            viewModel: NoteListViewModel(repository: dependencies.repository),
            selectedNoteID: $selectedNoteID
        )
    } detail: {
        if let selectedNoteID {
            NoteDetailView(
                repository: dependencies.repository,
                wikiLinkService: dependencies.wikiLinkService,
                noteID: selectedNoteID
            )
        } else {
            Text("Select a note")
        }
    }
    .frame(width: 800, height: 500)
}

@available(iOS 17, macOS 14, *)
#Preview("Empty notes list (macOS)") {
    @Previewable @State var selectedNoteID: UUID? = nil
    let dependencies = makeInMemoryDependencies()
    NavigationSplitView {
        NoteListView(
            repository: dependencies.repository,
            wikiLinkService: dependencies.wikiLinkService,
            viewModel: NoteListViewModel(repository: dependencies.repository),
            selectedNoteID: $selectedNoteID
        )
    } detail: {
        Text("No note selected")
    }
    .frame(width: 800, height: 500)
}
#endif
#endif

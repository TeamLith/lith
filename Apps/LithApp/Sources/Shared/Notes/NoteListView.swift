import SwiftUI
import Observation
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
        noteListContent
            .navigationTitle("Notes")
            .onAppear { Task { await viewModel.loadNotes() } }
            .task { await viewModel.loadNotes() }
            .toolbar {
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
            "No Notes Yet",
            systemImage: "note.text.badge.plus",
            description: Text("Your notes will appear here. Create your first note to get started.")
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
            Button {
                Task { await archive(noteID: note.id) }
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await moveToTrash(noteID: note.id) }
            } label: {
                Label("Trash", systemImage: "trash")
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
        Button {
            Task { await archive(noteID: note.id) }
        } label: {
            Label("Archive", systemImage: "archivebox")
        }

        Button(role: .destructive) {
            Task { await moveToTrash(noteID: note.id) }
        } label: {
            Label("Move to Trash", systemImage: "trash")
        }

        Button(role: .destructive) {
            Task { await delete(noteID: note.id) }
        } label: {
            Label("Delete Permanently", systemImage: "xmark.bin")
        }
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

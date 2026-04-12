import SwiftUI
import Lith

/// Note list screen showing pinned and recent note sections.
///
/// On macOS, note selection is communicated via the `selectedNote` binding so
/// that `RootView` can render the detail in the third split-view column.
/// On iOS the view relies on the `NavigationStack` already provided by `RootView`
/// and pushes `NoteDetailView` via `NavigationLink`.
@available(iOS 17, macOS 14, *)
struct NoteListView: View {
    @State private var viewModel: NoteListViewModel

#if os(macOS)
    @Binding var selectedNote: Note?

    init(repository: NoteRepository, selectedNote: Binding<Note?>) {
        self._viewModel = State(initialValue: NoteListViewModel(repository: repository))
        self._selectedNote = selectedNote
    }
#else
    init(repository: NoteRepository) {
        self._viewModel = State(initialValue: NoteListViewModel(repository: repository))
    }
#endif

    var body: some View {
        noteListContent
            .navigationTitle("Notes")
            .task { await viewModel.loadNotes() }
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
            .onTapGesture { selectedNote = note }
            .background(selectedNote?.id == note.id ? Color.accentColor.opacity(0.12) : Color.clear)
#else
        NavigationLink {
            NoteDetailView(note: note)
        } label: {
            noteRowContent(for: note)
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
}

// MARK: - Previews

#if DEBUG
@MainActor
private func makeInMemoryRepository(notes: [Note] = []) -> some NoteRepository {
    InMemoryNoteRepository(seed: notes)
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
    NavigationStack {
        NoteListView(repository: makeInMemoryRepository(notes: sampleNotes))
    }
}

@available(iOS 17, macOS 14, *)
#Preview("Empty notes list (iOS)") {
    NavigationStack {
        NoteListView(repository: makeInMemoryRepository())
    }
}
#endif

#if os(macOS)
@available(iOS 17, macOS 14, *)
#Preview("Populated notes list (macOS)") {
    @Previewable @State var selected: Note? = nil
    NavigationSplitView {
        NoteListView(
            repository: makeInMemoryRepository(notes: sampleNotes),
            selectedNote: $selected
        )
    } detail: {
        if let note = selected {
            NoteDetailView(note: note)
        } else {
            Text("Select a note")
        }
    }
    .frame(width: 800, height: 500)
}

@available(iOS 17, macOS 14, *)
#Preview("Empty notes list (macOS)") {
    @Previewable @State var selected: Note? = nil
    NavigationSplitView {
        NoteListView(
            repository: makeInMemoryRepository(),
            selectedNote: $selected
        )
    } detail: {
        Text("No note selected")
    }
    .frame(width: 800, height: 500)
}
#endif
#endif


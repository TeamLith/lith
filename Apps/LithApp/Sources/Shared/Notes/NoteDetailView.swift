import SwiftUI
import Lith

@available(iOS 17, macOS 14, *)
struct NoteDetailView: View {
    let onNoteChanged: @MainActor () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var viewModel: NoteDetailViewModel

    init(
        repository: NoteRepository,
        noteID: UUID,
        onNoteChanged: @escaping @MainActor () async -> Void = {}
    ) {
        self.onNoteChanged = onNoteChanged
        self._viewModel = State(initialValue: NoteDetailViewModel(noteID: noteID, repository: repository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError {
                ContentUnavailableView {
                    Label("Could Not Load Note", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadNote() }
                    }
                }
            } else {
                content
            }
        }
        .navigationTitle(viewModel.title.isEmpty ? "Untitled" : viewModel.title)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task { await viewModel.loadNote() }
        .onDisappear {
            Task { await onNoteChanged() }
        }
        .onChange(of: viewModel.title) { _, _ in
            viewModel.scheduleAutosave()
        }
        .onChange(of: viewModel.bodyMarkdown) { _, _ in
            viewModel.scheduleAutosave()
        }
        .onChange(of: viewModel.isPinned) { _, _ in
            viewModel.scheduleAutosave()
        }
        .toolbar { toolbarContent }
    }

    private var content: some View {
        Group {
            if isEditing {
                editorContent
            } else {
                previewContent
            }
        }
    }

    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock
                noteMetadata

                if viewModel.bodyMarkdown.isEmpty {
                    Text("No content yet.")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    Text(LocalizedStringKey(viewModel.bodyMarkdown))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let saveError = viewModel.saveError {
                    saveErrorBanner(saveError)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Untitled", text: $viewModel.title, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.title2.weight(.semibold))

            Toggle(isOn: $viewModel.isPinned) {
                Label("Pinned", systemImage: "pin.fill")
            }
            .toggleStyle(.switch)

            TextEditor(text: $viewModel.bodyMarkdown)
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let saveError = viewModel.saveError {
                saveErrorBanner(saveError)
            }
        }
        .padding()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title.isEmpty ? "Untitled" : viewModel.title)
                .font(.title.weight(.semibold))

            if viewModel.title.isEmpty {
                Text("Add a title in Edit mode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var noteMetadata: some View {
        HStack(spacing: 12) {
            if viewModel.isPinned {
                Label("Pinned", systemImage: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let updatedAt = viewModel.updatedAt {
                Label(
                    updatedAt.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func saveErrorBanner(_ error: Error) -> some View {
        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.red)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(isEditing ? "Done" : "Edit") {
                Task {
                    if isEditing {
                        _ = await viewModel.saveNow()
                        await onNoteChanged()
                    }
                    isEditing.toggle()
                }
            }
        }

        ToolbarItem(placement: .secondaryAction) {
            Menu("Actions") {
                Button {
                    Task {
                        guard await viewModel.archive() != nil else {
                            return
                        }
                        await onNoteChanged()
                        dismiss()
                    }
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }

                Button(role: .destructive) {
                    Task {
                        guard await viewModel.moveToTrash() != nil else {
                            return
                        }
                        await onNoteChanged()
                        dismiss()
                    }
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
        }
    }
}

#if DEBUG
@MainActor
private func makePreviewRepository() -> some NoteRepository {
    let note = Note(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
        title: "SwiftUI Notes",
        bodyMarkdown: "## Introduction\nSwiftUI is a **declarative** framework.\n\n- Easy\n- Concise\n- Cross-platform",
        isPinned: true
    )
    return InMemoryNoteRepository(seed: [note])
}

@MainActor
private let previewNoteID = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()

@available(iOS 17, macOS 14, *)
#Preview("Populated note") {
    let repository = makePreviewRepository()
    NavigationStack {
        NoteDetailView(repository: repository, noteID: previewNoteID)
    }
}

@available(iOS 17, macOS 14, *)
#Preview("Empty note") {
    let note = Note(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
        title: "",
        bodyMarkdown: ""
    )
    let repository = InMemoryNoteRepository(seed: [note])
    NavigationStack {
        NoteDetailView(
            repository: repository,
            noteID: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
        )
    }
}
#endif

import SwiftUI
import UniformTypeIdentifiers
import Lith

@available(iOS 17, macOS 14, *)
struct NoteDetailView: View {
    let onNoteChanged: @MainActor () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var exporting = false
    @State private var exportDocument: MarkdownFile?
    @State private var exportError: String?
    @State private var viewModel: NoteDetailViewModel

    init(
        repository: NoteRepository,
        wikiLinkService: WikiLinkServiceProtocol,
        noteID: UUID,
        onNoteChanged: @escaping @MainActor () async -> Void = {}
    ) {
        self.onNoteChanged = onNoteChanged
        self._viewModel = State(
            initialValue: NoteDetailViewModel(
                noteID: noteID,
                repository: repository,
                wikiLinkService: wikiLinkService
            )
        )
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
        .fileExporter(isPresented: $exporting, document: exportDocument,
                      contentType: UTType(filenameExtension: "md") ?? .plainText,
                      defaultFilename: viewModel.title.isEmpty ? "Untitled" : viewModel.title.replacingOccurrences(of: "/", with: "-")) { result in
            if case let .failure(error) = result { exportError = error.localizedDescription }
        }
        .alert("Could Not Export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: { Text(exportError ?? "") }
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
                    MarkdownPreview(markdown: viewModel.bodyMarkdown)
                }

                if let saveError = viewModel.saveError {
                    saveErrorBanner(saveError)
                }

                if !viewModel.backlinks.isEmpty {
                    backlinksSection
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

    private var backlinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Backlinks", systemImage: "link")
                .font(.headline)

            ForEach(viewModel.backlinks) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.subheadline.weight(.medium))

                    if !note.bodyMarkdown.isEmpty {
                        Text(note.bodyMarkdown)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
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
                Button("Export Markdown", systemImage: "square.and.arrow.up") {
                    do {
                        exportDocument = MarkdownFile(data: try MarkdownNoteService().export(title: viewModel.title, body: viewModel.bodyMarkdown))
                        exporting = true
                    } catch { exportError = error.localizedDescription }
                }
                if viewModel.isArchived || viewModel.isTrashed {
                    Button("Restore", systemImage: "arrow.uturn.backward") {
                        Task {
                            guard await viewModel.restore() != nil else { return }
                            await onNoteChanged()
                            dismiss()
                        }
                    }
                }
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
private func makePreviewDependencies() -> (repository: InMemoryNoteRepository, wikiLinkService: WikiLinkService) {
    let note = Note(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
        title: "SwiftUI Notes",
        bodyMarkdown: "## Introduction\nSwiftUI is a **declarative** framework.\n\n- Easy\n- Concise\n- Cross-platform",
        isPinned: true
    )
    let repository = InMemoryNoteRepository(seed: [note])
    let linkRepository = InMemoryLinkRepository()
    let wikiLinkService = WikiLinkService(noteRepository: repository, linkRepository: linkRepository)
    return (repository, wikiLinkService)
}

@MainActor
private let previewNoteID = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()

@available(iOS 17, macOS 14, *)
#Preview("Populated note") {
    let dependencies = makePreviewDependencies()
    NavigationStack {
        NoteDetailView(
            repository: dependencies.repository,
            wikiLinkService: dependencies.wikiLinkService,
            noteID: previewNoteID
        )
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
    let linkRepository = InMemoryLinkRepository()
    NavigationStack {
        NoteDetailView(
            repository: repository,
            wikiLinkService: WikiLinkService(noteRepository: repository, linkRepository: linkRepository),
            noteID: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
        )
    }
}
#endif

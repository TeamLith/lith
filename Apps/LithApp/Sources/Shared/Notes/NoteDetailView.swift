import SwiftUI
import Lith

/// Displays the full markdown content of a note and provides an in-place editor.
///
/// Editing state is local to this view. Persistence is wired in the
/// "Wire Note CRUD Flows Into UI" follow-up task.
@available(iOS 17, macOS 14, *)
struct NoteDetailView: View {
    let note: Note

    @State private var isEditing = false
    @State private var draftBody: String

    init(note: Note) {
        self.note = note
        self._draftBody = State(initialValue: note.bodyMarkdown)
    }

    var body: some View {
        Group {
            if isEditing {
                editorContent
            } else {
                previewContent
            }
        }
        .navigationTitle(note.title)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    // Persistence on Done is wired in the "Wire Note CRUD Flows Into UI" follow-up task.
                    isEditing.toggle()
                }
            }
        }
    }

    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                noteMetadata

                if draftBody.isEmpty {
                    Text("No content yet.")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    Text(LocalizedStringKey(draftBody))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var editorContent: some View {
        TextEditor(text: $draftBody)
            .font(.body.monospaced())
            .padding()
    }

    private var noteMetadata: some View {
        HStack(spacing: 12) {
            if note.isPinned {
                Label("Pinned", systemImage: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Label(
                note.updatedAt.formatted(date: .abbreviated, time: .shortened),
                systemImage: "clock"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
@available(iOS 17, macOS 14, *)
#Preview("Populated note") {
    NavigationStack {
        NoteDetailView(
            note: Note(
                title: "SwiftUI Notes",
                bodyMarkdown: "## Introduction\nSwiftUI is a **declarative** framework.\n\n- Easy\n- Concise\n- Cross-platform",
                isPinned: true
            )
        )
    }
}

@available(iOS 17, macOS 14, *)
#Preview("Empty note") {
    NavigationStack {
        NoteDetailView(
            note: Note(
                title: "Untitled",
                bodyMarkdown: ""
            )
        )
    }
}
#endif

import AppIntents
import Lith

struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"
    static let description = IntentDescription("Save a text note in Lith on this device.")
    static let openAppWhenRun = false

    @Parameter(title: "Title", requestValueDialog: "What should the note be called?")
    var title: String

    @Parameter(title: "Text", default: "")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create note \(\.$title) with \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dependencies = try AppDependencyContainer(mode: .live)
        let note = try await NoteCaptureService(repository: dependencies.noteRepository)
            .createNote(title: title, content: text)
        return .result(dialog: "Created \(note.title) in Lith.")
    }
}

struct LithShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CreateNoteIntent(), phrases: ["Create a note in \(.applicationName)"],
                    shortTitle: "Create Note", systemImageName: "note.text")
    }
}

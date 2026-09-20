import SwiftUI
import Lith

struct ActionItemsView: View {
    @Bindable var viewModel: ActionItemsViewModel
    let bodyText: String
    let referenceDate: Date
    @State private var editing: ActionEditorState?
    @State private var reviewingExport = false
    @State private var deleting: ActionItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Action items", systemImage: "checklist").font(.headline)
            if let error = viewModel.errorMessage {
                Text(error).font(.callout).foregroundStyle(.red)
                Button("Reload actions") { Task { await viewModel.load() } }
            }
            if viewModel.isBusy { ProgressView() }
            if viewModel.items.isEmpty {
                Text("No accepted actions yet.").foregroundStyle(.secondary)
            }
            ForEach(viewModel.items) { item in
                HStack(alignment: .top) {
                    Button {
                        Task { await viewModel.setCompleted(id: item.id, completed: item.status != .done) }
                    } label: {
                        Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                    }.accessibilityLabel(item.status == .done ? "Reopen \(item.task)" : "Complete \(item.task)")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.task).strikethrough(item.status == .done)
                        if let assignee = item.assignee { Text(assignee).font(.caption).foregroundStyle(.secondary) }
                        if let date = item.dueDate { Text(date, style: .date).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Button("Edit") { editing = ActionEditorState(item: item) }
                    Button(role: .destructive) { deleting = item } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Delete \(item.task)")
                }
            }
            Divider()
            Button("Find action suggestions") {
                Task { await viewModel.propose(from: bodyText, referenceDate: referenceDate) }
            }
            Text("Review suggestions before accepting. Only accepted actions can be shared.")
                .font(.caption).foregroundStyle(.secondary)
            if viewModel.hasExtracted && viewModel.drafts.isEmpty {
                Text("No new suggestions to review.").foregroundStyle(.secondary)
            }
            ForEach(viewModel.drafts) { draft in
                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.task)
                    if let assignee = draft.assignee { Text("Assignee: \(assignee)").font(.caption) }
                    if let date = draft.dueDate { Text("Suggested date: \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                    HStack {
                        Button("Review and accept") { editing = ActionEditorState(draft: draft) }
                        Button("Dismiss") { viewModel.dismissDraft(draft.id) }
                    }
                }.padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            if !viewModel.exportText.isEmpty {
                Button("Review accepted actions for sharing") { reviewingExport = true }
            }
        }
        .disabled(viewModel.isBusy)
        .task { await viewModel.load() }
        .sheet(item: $editing) { edit in
            ActionItemEditor(initial: edit, errorMessage: viewModel.errorMessage) { revised in
                let success: Bool
                if var draft = revised.draft {
                    draft.task = revised.task
                    draft.assignee = revised.assignee.isEmpty ? nil : revised.assignee
                    draft.dueDate = revised.hasDate ? revised.dueDate : nil
                    success = await viewModel.accept(draft)
                } else {
                    success = await viewModel.update(id: revised.id, task: revised.task, assignee: revised.assignee,
                                                     dueDate: revised.hasDate ? revised.dueDate : nil)
                }
                if success { editing = nil }
                return success
            }
        }
        .sheet(isPresented: $reviewingExport) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review accepted actions").font(.headline)
                Text("Sharing opens the system share sheet. It does not automatically create reminders.")
                    .font(.callout).foregroundStyle(.secondary)
                ScrollView { Text(viewModel.exportText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                HStack {
                    Button("Cancel") { reviewingExport = false }
                    Spacer()
                    ShareLink(item: viewModel.exportText) { Label("Share accepted actions", systemImage: "square.and.arrow.up") }
                        .disabled(viewModel.exportText.isEmpty)
                }
            }.padding().frame(minWidth: 300, idealWidth: 460, minHeight: 300)
        }
        .confirmationDialog("Delete this action?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete action", role: .destructive) {
                if let id = deleting?.id { Task { await viewModel.delete(id: id) } }
                deleting = nil
            }
        } message: { Text(deleting?.task ?? "") }
    }
}

private struct ActionEditorState: Identifiable {
    let id: UUID
    var draft: ActionItemDraft?
    var task: String
    var assignee: String
    var hasDate: Bool
    var dueDate: Date

    init(item: ActionItem) {
        id = item.id; task = item.task; assignee = item.assignee ?? ""
        hasDate = item.dueDate != nil; dueDate = item.dueDate ?? Date()
    }
    init(draft: ActionItemDraft) {
        id = draft.id; self.draft = draft; task = draft.task; assignee = draft.assignee ?? ""
        hasDate = draft.dueDate != nil; dueDate = draft.dueDate ?? Date()
    }
}

private struct ActionItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var state: ActionEditorState
    @State private var saving = false
    @State private var failed = false
    let errorMessage: String?
    let save: (ActionEditorState) async -> Bool

    init(initial: ActionEditorState, errorMessage: String?, save: @escaping (ActionEditorState) async -> Bool) {
        _state = State(initialValue: initial)
        self.errorMessage = errorMessage
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.draft == nil ? "Edit action" : "Review suggestion").font(.headline)
            Form {
                TextField("Task", text: $state.task, axis: .vertical)
                TextField("Assignee", text: $state.assignee)
                Toggle("Due date", isOn: $state.hasDate)
                if state.hasDate { DatePicker("Due", selection: $state.dueDate, displayedComponents: .date) }
            }
            if failed { Text(errorMessage ?? "Could not save the action. Try again.").foregroundStyle(.red) }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button(state.draft == nil ? "Save" : "Accept action") {
                    saving = true
                    Task {
                        failed = !(await save(state))
                        saving = false
                    }
                }.disabled(state.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .disabled(saving)
        .padding().frame(minWidth: 300, idealWidth: 460, minHeight: 300)
    }
}

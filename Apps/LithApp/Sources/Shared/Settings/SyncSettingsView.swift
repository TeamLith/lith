import SwiftUI
import Lith

struct SyncSettingsView: View {
    @Bindable var viewModel: SyncSettingsViewModel

    var body: some View {
        Form {
            Section("iCloud Sync") {
                Toggle("Enable iCloud Sync", isOn: Binding(get: { viewModel.isEnabled }, set: { viewModel.setEnabled($0) }))
                    .disabled(!viewModel.isAvailable)
                if let reason = viewModel.unavailableReason {
                    Label(reason, systemImage: "icloud.slash").foregroundStyle(.secondary)
                }
                LabeledContent("Status", value: viewModel.statusTitle)
                if let date = viewModel.lastSuccessfulSync {
                    LabeledContent("Last successful sync") { Text(date, format: .dateTime) }
                } else {
                    LabeledContent("Last successful sync", value: "Not yet")
                }
                if let date = viewModel.nextRetryAt {
                    LabeledContent("Retry after") { Text(date, format: .dateTime) }
                }
                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
                Button(viewModel.errorMessage == nil ? "Sync Now" : "Retry Sync") {
                    Task { await viewModel.syncNow() }
                }
                .disabled(!viewModel.isEnabled || !viewModel.isForeground || viewModel.isSyncing)
                if viewModel.isSyncing { ProgressView("Syncing with iCloud…") }
            }
            Section("Your Data") {
                Text("Sync is off by default. Disabling sync keeps local notes and existing iCloud copies.")
                Text("When enabled, Lith syncs on returning to the foreground and every minute while a window is active. Backgrounding pauses further requests. Use Sync Now after an edit to sync immediately.")
                Text("Audio metadata and transcripts can sync; recording files currently stay on the recording device.")
            }
            Section("Retained Conflicts (\(viewModel.conflicts.count))") {
                if viewModel.conflicts.isEmpty {
                    Text("No retained conflicts.").foregroundStyle(.secondary)
                }
                ForEach(viewModel.conflicts.reversed()) { conflict in
                    DisclosureGroup {
                        Text("Detected \(conflict.detectedAt.formatted())").font(.caption)
                        conflictCopy("Local copy", record: conflict.local)
                        conflictCopy("Cloud copy", record: conflict.remote)
                        if viewModel.unresolvedConflictIDs.contains(conflict.id) {
                            HStack {
                                Button("Keep Local Version") { Task { await viewModel.resolve(conflict, keepLocal: true) } }
                                Button("Use Cloud Version") { Task { await viewModel.resolve(conflict, keepLocal: false) } }
                            }
                            .disabled(!viewModel.isEnabled || !viewModel.isForeground || viewModel.isSyncing)
                        }
                    } label: {
                        Text(conflictTitle(conflict.local))
                    }
                }
                Text("Both versions are retained. Conflicts without a reliable edit time offer an explicit choice. After choosing, use Sync Now to finish syncing. Historical resolved copies remain readable and can be copied.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { await viewModel.restoreStatus() }
    }

    @ViewBuilder
    private func conflictCopy(_ label: String, record: CloudRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.headline)
            Text(record.modifiedAt, format: .dateTime).font(.caption)
            if record.deleted {
                Text("Deleted on this copy")
            } else if let note = try? record.decode(Note.self) {
                Text(note.title).font(.subheadline.bold())
                Text(note.bodyMarkdown).textSelection(.enabled)
            } else {
                Text(conflictDescription(record)).textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func conflictDescription(_ record: CloudRecord) -> String {
        switch record.kind {
        case .feed:
            guard let feed = try? record.decode(RSSFeed.self) else { break }
            return "\(feed.title)\n\(feed.feedURL.absoluteString)\nCategory: \(feed.category ?? "None")\n\(feed.isActive ? "Active" : "Paused")"
        case .item:
            guard let item = try? record.decode(RSSItem.self) else { break }
            return "\(item.title)\n\(item.linkURL.absoluteString)\nStatus: \(item.status.rawValue)\n\n\(item.content)"
        case .audio:
            guard let audio = try? record.decode(AudioRecording.self) else { break }
            return "Audio recording · \(Int(audio.duration)) seconds\n\n\(audio.transcript)"
        case .action:
            guard let action = try? record.decode(ActionItem.self) else { break }
            return "\(action.task)\nAssignee: \(action.assignee ?? "Unassigned")\nStatus: \(action.status.rawValue)"
        case .link: return "A note link was changed or deleted. Retain the local version to keep your current connection."
        default: break
        }
        return "This copy cannot be displayed by this version of Lith."
    }

    private func conflictTitle(_ record: CloudRecord) -> String {
        if let note = try? record.decode(Note.self) { return note.title.isEmpty ? "Untitled Note" : note.title }
        return "\(record.kind.rawValue) · \(record.entityID.uuidString.prefix(8))"
    }
}

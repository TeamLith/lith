import SwiftUI
import Lith

@available(iOS 17, macOS 14, *)
struct AudioNoteSection: View {
    @State private var model: AudioNoteViewModel
    @Environment(\.scenePhase) private var scenePhase
    init(noteID: UUID, repository: AudioRecordingRepository) {
        let recorder = AudioRecorderService(repository: repository, driver: AppleAudioRecordingDriver())
        self._model = State(initialValue: AudioNoteViewModel(
            noteID: noteID, repository: repository, recorder: recorder,
            transcription: TranscriptionService(repository: repository, driver: AppleSpeechTranscriptionDriver()),
            playback: AppleAudioPlaybackDriver()))
    }
    init(noteID: UUID, services: AudioServices) {
        self._model = State(initialValue: AudioNoteViewModel(noteID: noteID, services: services))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Audio recordings", systemImage: "waveform").font(.headline)
            HStack {
                if model.activeRecordingID != nil {
                    Button("Stop recording", systemImage: "stop.circle.fill") { Task { await model.stopRecording() } }
                        .tint(.red)
                    Text(Self.duration(model.recordingDuration)).monospacedDigit()
                } else {
                    Button("Record audio", systemImage: "mic.fill") { Task { await model.startRecording() } }
                        .disabled(model.transcribingID != nil || model.isRecordingElsewhere)
                }
                if model.isBusy { ProgressView().controlSize(.small) }
            }
            .disabled(model.isBusy)
            if model.isRecordingElsewhere { Text("Recording in another note or window.").font(.caption).foregroundStyle(.secondary) }
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
                Button("Reload recordings") { Task { await model.load() } }
            }
            ForEach(model.recordings) { recording in
                AudioRecordingRow(recording: recording, model: model)
            }
            if model.recordings.isEmpty {
                Text("Record a voice note, then transcribe it on this device.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .task {
            await model.load()
            while !Task.isCancelled {
                await model.tick()
                do { try await Task.sleep(for: .milliseconds(250)) } catch { break }
            }
        }
        .onDisappear { Task { await model.stopForNavigation() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await model.stopForNavigation() } }
        }
    }
    static func duration(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

@available(iOS 17, macOS 14, *)
private struct AudioRecordingRow: View {
    let recording: AudioRecording
    @Bindable var model: AudioNoteViewModel
    @State private var draft = ""
    @State private var editing = false
    @State private var confirmDelete = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recording.recordedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline)
                Spacer()
                Text(AudioNoteSection.duration(recording.duration)).font(.caption).monospacedDigit()
            }
            if recording.recordingState == .interrupted || recording.recordingState == .failed {
                Text(recording.recordingState == .interrupted ? "Interrupted recording" : "Recording failed")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if recording.recordingState != .recording {
                HStack {
                    Button(model.playingID == recording.id && model.isPlaying ? "Pause" : "Play",
                           systemImage: model.playingID == recording.id && model.isPlaying ? "pause.fill" : "play.fill") {
                        model.togglePlayback(recording)
                    }
                    .disabled(model.activeRecordingID != nil || model.isRecordingElsewhere)
                    if model.playingID == recording.id {
                        Text(AudioNoteSection.duration(model.playbackTime)).font(.caption).monospacedDigit()
                    }
                    if model.transcribingID == recording.id {
                        ProgressView().controlSize(.small)
                        Button("Cancel") { model.cancelTranscription() }
                    } else {
                        Button(recording.status == .failed ? "Retry transcription" : "Transcribe") {
                            model.startTranscription(recording)
                        }
                        .disabled(model.transcribingID != nil || model.activeRecordingID != nil || model.isRecordingElsewhere || editing)
                    }
                    Spacer()
                    Button("Delete recording", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .labelStyle(.iconOnly)
                        .disabled(model.transcribingID == recording.id)
                }
            }
            if recording.status == .processing { Text("Transcribing on device…").font(.caption).foregroundStyle(.secondary) }
            if let message = recording.errorMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            if editing {
                TextEditor(text: $draft).frame(minHeight: 120)
                    .accessibilityLabel("Transcript corrections")
                HStack {
                    Button("Save transcript") {
                        Task { await model.saveTranscript(recordingID: recording.id, text: draft); if model.errorMessage == nil { editing = false } }
                    }
                    Button("Cancel editing") { editing = false }
                }
            } else if !recording.transcript.isEmpty {
                Text(recording.transcript).textSelection(.enabled)
                Button("Edit transcript") { draft = recording.transcript; editing = true }
                    .disabled(model.transcribingID == recording.id)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .confirmationDialog("Delete this recording and its transcript?", isPresented: $confirmDelete) {
            Button("Delete recording", role: .destructive) { Task { await model.delete(recording) } }
        }
    }
}

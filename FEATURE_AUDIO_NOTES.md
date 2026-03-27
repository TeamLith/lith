# Feature: Audio Notes

## V1 requirements

- Record audio attached to a note.
- Save audio file locally/iCloud file location and reference via `AudioNote`.
- Transcribe on device via Speech framework.
- Show transcript inside note detail.

## Later (explicitly out of V1)

- Speaker diarization
- Dense timestamp editing tools
- Advanced summarization

## Task: Audio Recording Infrastructure

- Input specs:
  - `DATA_MODEL.md` (`AudioNote`)
- Deliverables:
  - Recording service + file lifecycle
- Steps:
  - [ ] Implement `AudioRecorderService` (AVAudioRecorder/Engine).
  - [ ] Persist deterministic filenames by note/recording ID.
  - [ ] Add error handling and interruption recovery.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Transcription Service

- Input specs:
  - `ARCHITECTURE.md`
- Deliverables:
  - Speech transcription service + status updates
- Steps:
  - [ ] Implement `TranscriptionService` with Speech framework.
  - [ ] Persist transcript + `transcriptionStatus`.
  - [ ] Expose progress and completion callbacks.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

## Task: Audio UI

- Input specs:
  - `ARCHITECTURE.md`
- Deliverables:
  - Controls in note detail view
- Steps:
  - [ ] Add record/stop controls.
  - [ ] Show duration/progress and playback controls.
  - [ ] Render transcript and editable corrections.
- Status: TODO
- Agent: unassigned
- Last updated: 2026-03-27

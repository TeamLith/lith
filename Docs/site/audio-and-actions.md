---
title: Audio and Actions
nav_order: 5
---

# Audio and Actions

Lith is designed to turn spoken capture into useful follow-through.

## Workflow

1. Open a note in preview mode and choose **Record audio**. Allow microphone access when prompted.
2. Watch the elapsed duration, then choose **Stop recording**. Leaving the note or sending Lith to the background stops capture and retains the recording.
3. Choose **Play** or **Pause** to listen. Choose **Transcribe** to generate an on-device transcript and allow Speech Recognition permission if prompted.
4. Partial text appears while transcription runs. Choose **Cancel** to stop, or **Retry transcription** after a failure.
5. Choose **Edit transcript**, make corrections, and choose **Save transcript**. Corrections are saved with the recording.
6. Use the recording's trash button and confirm to remove its audio and transcript.

## Why it matters

This workflow reduces the gap between capture and follow-up, especially for meeting-heavy work.

## Availability

Audio recording infrastructure saves each capture beneath a stable note and recording identifier in the local app data folder. Recording requests microphone permission first. A denied request creates no recording. Interruptions retain available audio and record an explanatory state; an unfinished recording discovered after relaunch is marked interrupted.

On-device transcription requests Speech Recognition permission and checks support for your device and language. Audio is never sent to a server as a fallback. When support is unavailable or permission is denied, the saved recording remains available and the failure explains how to retry. Partial transcripts and completion status are saved as recognition progresses. Cancellation or closing Lith leaves a retryable failed transcription and retains available text.

Action extraction arrives separately. Audio files currently remain local; metadata uses portable relative file identities so enabling sync does not expose a device-specific filesystem path.

## Siri and Shortcuts

The **Create Note** action is available in Shortcuts on iPhone, iPad and Mac. Supply a title and optional text, or say “Create a note in Lith” to Siri. Lith saves locally and confirms only after the note is stored. Empty notes are rejected. The action does not require iCloud. Siri availability and indexing depend on your device settings and installing a signed app build.

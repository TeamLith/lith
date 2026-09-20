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

## Action suggestions

Action extraction suggests drafts from English transcript sentences such as **I will**, **We need to**, **Alice will**, **TODO:**, **Action item:**, and **Follow up**. Ordinary mentions of a date or “by” do not create tasks. Negative commitments such as “We will not publish” are ignored.

Suggestions can include a named assignee and an interpreted due date. Supported dates include today, tomorrow, EOD (17:00), an ISO date such as `2026-10-01`, “in two weeks,” and “next Friday.” Relative dates use the supplied transcript reference date and local calendar; “next Friday” means the next occurrence strictly after that day. Ambiguous dates remain empty for review.

Nothing is saved until you accept a draft. Accepting an already accepted suggestion preserves its existing edits and completion state. Repeating extraction hides previously accepted suggestions. Action storage is local; extraction does not create reminders or send anything to another app.

## Review and manage actions

In a note’s reading view, the **Action items** section lists accepted tasks. Select **Find action suggestions** to inspect the note text and any available linked transcript. This does not save the suggestions.

For each suggestion, select **Review and accept**, check or edit its task, assignee, and due date, then select **Accept action**. You can dismiss a suggestion without saving it. Dismissed suggestions can return if you run extraction again.

- Select the circle beside an accepted action to mark it done; select it again to reopen it.
- Select **Edit** to change its task, assignee, or due date. Turn off **Due date** to remove the date.
- Select the trash button and confirm to delete an accepted action. Extracting its original text again can suggest it again.
- Select **Review accepted actions for sharing**, inspect the checklist, then select **Share accepted actions** to open the system share sheet. Unaccepted suggestions are never included. Sharing does not automatically create reminders or send messages.

Changes are saved locally. If a save fails, an error appears and the existing checklist remains available for retry. Suggestion dates are heuristics; check them before acceptance.

## Recording availability

Audio recording infrastructure saves each capture beneath a stable note and recording identifier in the local app data folder. Recording requests microphone permission first. A denied request creates no recording. Interruptions retain available audio and record an explanatory state; an unfinished recording discovered after relaunch is marked interrupted.

On-device transcription requests Speech Recognition permission and checks support for your device and language. Audio is never sent to a server as a fallback. When support is unavailable or permission is denied, the saved recording remains available and the failure explains how to retry. Partial transcripts and completion status are saved as recognition progresses. Cancellation or closing Lith leaves a retryable failed transcription and retains available text.

Audio files currently remain local; metadata uses portable relative file identities so enabling sync does not expose a device-specific filesystem path.

## Siri and Shortcuts

The **Create Note** action is available in Shortcuts on iPhone, iPad and Mac. Supply a title and optional text, or say “Create a note in Lith” to Siri. Lith saves locally and confirms only after the note is stored. Empty notes are rejected. The action does not require iCloud. Siri availability and indexing depend on your device settings and installing a signed app build.

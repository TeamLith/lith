---
title: Audio and Actions
nav_order: 5
---

# Audio and Actions

Lith is designed to turn spoken capture into useful follow-through.

## Workflow

- Record audio tied to a note.
- Generate a transcript when on-device support is available.
- Extract action items from meetings or spoken notes.

## Why it matters

This workflow reduces the gap between capture and follow-up, especially for meeting-heavy work.

## Action suggestions

Action extraction suggests drafts from English transcript sentences such as **I will**, **We need to**, **Alice will**, **TODO:**, **Action item:**, and **Follow up**. Ordinary mentions of a date or “by” do not create tasks. Negative commitments such as “We will not publish” are ignored.

Suggestions can include a named assignee and an interpreted due date. Supported dates include today, tomorrow, EOD (17:00), an ISO date such as `2026-10-01`, “in two weeks,” and “next Friday.” Relative dates use the supplied transcript reference date and local calendar; “next Friday” means the next occurrence strictly after that day. Ambiguous dates remain empty for review.

Nothing is saved until you accept a draft. Accepting an already accepted suggestion preserves its existing edits and completion state. Repeating extraction hides previously accepted suggestions. Action storage is local; extraction does not create reminders or send anything to another app.

## Availability

Audio recording infrastructure saves each capture beneath a stable note and recording identifier in the local app data folder. Recording requests microphone permission first. A denied request creates no recording. Interruptions retain available audio and record an explanatory state; an unfinished recording discovered after relaunch is marked interrupted.

On-device transcription requests Speech Recognition permission and checks support for your device and language. Audio is never sent to a server as a fallback. When support is unavailable or permission is denied, the saved recording remains available and the failure explains how to retry. Partial transcripts and completion status are saved as recognition progresses. Cancellation or closing Lith leaves a retryable failed transcription and retains available text.

Recording controls arrive in a separate stage. Audio files currently remain local; metadata uses portable relative file identities so enabling sync does not expose a device-specific filesystem path.

## Siri and Shortcuts

The **Create Note** action is available in Shortcuts on iPhone, iPad and Mac. Supply a title and optional text, or say “Create a note in Lith” to Siri. Lith saves locally and confirms only after the note is stored. Empty notes are rejected. The action does not require iCloud. Siri availability and indexing depend on your device settings and installing a signed app build.

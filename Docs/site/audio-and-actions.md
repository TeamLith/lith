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

## Availability

Audio recording infrastructure saves each capture beneath a stable note and recording identifier in the local app data folder. Recording requests microphone permission first. A denied request creates no recording. Interruptions retain available audio and record an explanatory state; an unfinished recording discovered after relaunch is marked interrupted.

Recording controls, transcription, and action extraction arrive in separate stages. Audio files currently remain local; metadata uses portable relative file identities so enabling sync does not expose a device-specific filesystem path.

## Siri and Shortcuts

The **Create Note** action is available in Shortcuts on iPhone, iPad and Mac. Supply a title and optional text, or say “Create a note in Lith” to Siri. Lith saves locally and confirms only after the note is stored. Empty notes are rejected. The action does not require iCloud. Siri availability and indexing depend on your device settings and installing a signed app build.

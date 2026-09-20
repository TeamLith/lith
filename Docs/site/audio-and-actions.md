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

The extraction and acceptance services are available. The transcript review/checklist interface and audio workflow may arrive in stages across builds.

# Voice Expense Tracker: First Version

Status: product scope confirmed by the user on October 20, 2026. Implementation is authorized for tickets 01–06; see [the ticket plan](ticket-plan.md) and [verification instructions](verification-01-03.md). macOS tests and device acceptance checks remain pending, including for tickets 01–03. Tickets 07–12 below are still planned.

This is the short scope summary. The detailed local specification is split into [overview and user stories](specs/README.md), [capture and reliability](specs/01-capture.md), [history and summaries](specs/02-history-and-summaries.md), and [Google Sheets integration](specs/03-google-sheets.md). Use the [acceptance checklist](specs/acceptance-checklist.md) to compare a future app with the agreed scope.

## Purpose

A personal iPhone app for quickly recording expenses in Indonesian, English, or a mixture of both. Rupiah is the only currency in version one.

## Capture

- A Back Tap shortcut launches voice capture. Unlocking is acceptable. Every fresh capture starts in voice mode, with a visible switch to keyboard entry.
- Process speech after a short silence; offer Done and Cancel. Ask for missing or ambiguous information, including payment method, and accept spoken follow-ups for the same expense.
- Keyboard entry offers amount, description, payment source, payment channel, and date, with an explicit Save button. Complete manual entries work offline.
- Combine clearly related items purchased together using one payment method into one expense. Resolve relative dates using the phone's local date; default to capture date when no date is supplied.
- Manage payment sources in an editable list; ask before adding unfamiliar sources.
- Automatically save complete, unambiguous spoken expenses. Show Saved only after successful local storage, with amount, description, payment method, Edit, and Undo.
- Show a system notification when appropriate in the background, if permitted; default lock-screen content is generic.

## Reliability and privacy

- Repeated shortcut activation during listening, clarification, or saving returns to the same capture. Save retries create at most one expense.
- A new capture with the same amount, description, and payment source as an expense saved within two minutes asks whether another expense is intended.
- Processing failure preserves captured text as a draft, excluded from totals, with Retry and editing. If no text was captured, offer typing or another recording.
- Interruptions stop listening and preserve captured text. The next activation offers Resume draft or Start new; do not resume microphone recording automatically. Explicit Cancel discards the capture.
- Online interpretation is allowed. Discard captured audio after processing; retain text only as needed for drafts or corrections. Verify remote provider retention when selecting a provider.

## History and summaries

- Present expenses grouped by date, with amount, description, and combined payment method as the primary columns. Support editing and deletion.
- A Summary screen shows the selected month's total and that year's total, with month/year selection.
- Summaries use saved local expenses, including pending uploads; drafts are excluded. Edits, deletion, and Undo update totals.

## Google Sheets

- Save locally first and upload automatically when connected, without an intermediate Excel file.
- Distinguish Saved on phone, Pending upload, and Added to Google Sheets statuses.
- Use one linked spreadsheet per expense year, named Expense Tracker — YYYY. Use monthly tabs named 01 January through 12 December, created when first needed.
- Route by expense date. Date edits can move an expense between tabs or yearly spreadsheets.
- The app controls adding, editing, and deleting expenses and propagates those changes to Sheets. Direct spreadsheet edits do not update the app.
- Reconcile uploads and retries to avoid duplicate remote rows.

## Deferred

- Restoring app history from Google Sheets, including after reinstalling the app.
- Two-way synchronization, budgets, charts, category analysis, multiple currencies, permanent transcripts, and audio playback.

## Validation before implementation commitments

- Verify Back Tap, shortcut launch, voice permissions, capture lifecycle, and notification behavior on the user's iPhone.
- Select a voice interpretation provider and verify retention behavior.
- Prove Google authorization and reconciliation of uploads, edits, deletions, date moves, and interrupted retries.

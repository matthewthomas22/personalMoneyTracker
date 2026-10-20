# Voice Expense Tracker: Agreed First Version

Status: product scope confirmed on October 20, 2026. Specification only; do not implement yet.

## Problem Statement

Recording everyday expenses takes too much interaction. The user wants to quickly describe a purchase on an iPhone, capture its amount and payment method, and review monthly and yearly spending. Speaking is sometimes impractical, so keyboard entry must also be available. Repeated shortcut activation, recognition errors, and unreliable connectivity must not create incorrect or duplicate records.

## Solution

A personal iPhone expense tracker launched through a Back Tap shortcut. Fresh shortcut captures start with voice and offer a keyboard alternative. The app saves rupiah expenses locally, asks for missing information, and automatically uploads records to yearly Google spreadsheets with monthly tabs. The same app provides history and monthly and yearly totals.

Detailed behavior:

- [Capture and reliability](01-capture.md)
- [History and summaries](02-history-and-summaries.md)
- [Google Sheets integration](03-google-sheets.md)
- [Acceptance checklist](acceptance-checklist.md)

## User Stories

1. As the owner, I want Back Tap to launch capture, so that recording spending takes little effort.
2. As the owner, I want every fresh Back Tap capture to start in voice mode, so that I can speak regardless of my last input mode.
3. As the owner, I want to unlock before capture when required, so that the flow fits supported iPhone behavior.
4. As the owner, I want to speak Indonesian, English, or a mixture, so that I can describe spending naturally.
5. As the owner, I want spoken rupiah amounts interpreted correctly, so that records reflect what I spent.
6. As the owner, I want amount, description, and payment method recorded, so that I know how much I spent, on what, and from which source.
7. As the owner, I want payment channel and payment source distinguished, so that QRIS GoPay and QRIS SeaBank remain meaningful.
8. As the owner, I want missing or ambiguous information clarified, so that the app does not guess important fields.
9. As the owner, I want spoken follow-ups to finish the current capture, so that answering a question does not create another expense.
10. As the owner, I want related items from one purchase combined, so that one payment creates one expense.
11. As the owner, I want relative purchase dates understood, so that yesterday's purchase is recorded on the correct date.
12. As the owner, I want a visible keyboard alternative, so that I can record quietly or in noisy surroundings.
13. As the owner, I want complete manual entries saved offline, so that typing an expense does not require a connection.
14. As the owner, I want an editable source list and alias recognition, so that payment-source names stay consistent.
15. As the owner, I want approval before an unfamiliar source is added, so that recognition mistakes do not pollute my list.
16. As the owner, I want complete spoken expenses saved automatically, so that I avoid unnecessary confirmation steps.
17. As the owner, I want repeated shortcut activation to reuse the active capture, so that accidental Back Taps do not duplicate spending.
18. As the owner, I want possible repeat purchases flagged without being forbidden, so that legitimate identical purchases remain possible.
19. As the owner, I want failed interpretation to preserve captured text as a draft, so that I can retry or correct it.
20. As the owner, I want interruptions to stop listening and preserve captured text, so that useful input survives without unexpected recording.
21. As the owner, I want explicit cancellation to discard the capture, so that unwanted input is not saved.
22. As the owner, I want a save confirmation with an expense summary, so that I can verify what was recorded.
23. As the owner, I want Edit and Undo after saving, so that I can correct mistakes quickly.
24. As the owner, I want private lock-screen confirmation, so that expense details are not exposed by default.
25. As the owner, I want history grouped by date, so that I can review, edit, and delete expenses.
26. As the owner, I want monthly and yearly totals, so that I can understand spending without complex analysis.
27. As the owner, I want pending-upload expenses included in totals, so that poor connectivity does not distort summaries.
28. As the owner, I want direct Google Sheets uploads, so that I can view spreadsheet history without managing Excel files on my phone.
29. As the owner, I want one named spreadsheet per year and one tab per month, so that history remains organized.
30. As the owner, I want spreadsheet placement based on purchase date, so that delayed entry does not change reporting periods.
31. As the owner, I want app edits and deletions reflected in Sheets, so that it follows my app records.
32. As the owner, I want local save and upload statuses distinguished, so that I know whether Sheets received an expense.
33. As the owner, I want retries to avoid duplicate records locally and remotely, so that failures do not inflate spending.
34. As the owner, I want audio discarded after processing, so that recordings do not become a permanent archive.

## Implementation Decisions

- Personal iPhone use; rupiah is the only currency.
- Local saved expenses are authoritative for history and totals. Sheets is an automatically updated reporting copy.
- Fields include amount, description, payment source, payment channel, and expense date. Combine channel and source as payment method in the primary presentation.
- Every fresh shortcut capture starts in voice mode. Existing capture and interrupted-draft handling take precedence over creating another capture.
- Online interpretation is permitted. No provider, model, backend, storage library, or iOS framework has been selected.
- Distinguish logical expenses from repeated save/upload attempts. Stable record identity or an equivalent mechanism is required; the exact schema and reconciliation algorithm remain implementation choices.
- Use Back Tap and a shortcut; do not assume a global volume-button launcher.
- No application modules, API contracts, or database schema exist yet. The functional areas describe behavior, not prescribed code structure.

## Testing Decisions

- Test externally observable behavior: saved records, prompts, totals, confirmation states, and spreadsheet rows. Do not mirror private implementation steps.
- Proposed primary seam: the complete expense workflow, supplying captured text or manual input and observing saved records, summaries, and synchronization outcomes. This is a proposal for later implementation, not an already approved test architecture.
- Cover capture, drafts, duplicate protection, history, summaries, and synchronization through that seam where practical. Simulate interpreter and network outcomes for repeatable failure scenarios.
- Supplement with real-device checks for Back Tap, microphone permissions, interruptions, keyboard switching, and notification privacy. Verify Google authorization and spreadsheet results against a dedicated test spreadsheet.
- The folder currently contains design documentation only. There are no existing application seams, tests, or ADRs to reuse.
- Acceptance criteria are the comparison baseline. No app behavior has been tested or marked as passing.

## Out of Scope

- Implementation in the current task.
- Restoring app history from Sheets, including after reinstalling the app.
- Two-way synchronization or importing direct spreadsheet edits.
- Budgets, charts, category analysis, multiple currencies, shared accounts, permanent transcripts, and audio playback.
- A separate summary app; summaries belong in the expense app.
- Required temporary Excel or CSV export; direct Sheets integration was selected instead.
- Guaranteed capture while locked or global interception of volume-down.

## Further Notes

- Validate Back Tap, permissions, notifications, and microphone behavior on the actual iPhone. Its model and minimum supported iOS version are not specified.
- Select an interpretation provider and verify its retention policy. Permission to process online does not establish remote retention guarantees.
- Silence thresholds, Undo availability duration, and uncertainty thresholds remain implementation details to validate against the agreed behavior.
- Spreadsheet history remains accessible independently, but the app will not reload it after reinstalling.
- This is a local specification at the user's request. Issue-tracker publication is outside this task.

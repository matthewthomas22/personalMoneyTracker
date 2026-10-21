# Proposed Tickets: Voice Expense Tracker

Status: the user authorized tickets 01–03 on October 20, 2026, and the next three tickets (04–06), with one sub-agent per ticket, on October 21. Tickets 07–12 remain proposed and outside the current implementation scope. macOS tests and device verification of earlier tickets have not yet been performed. This document is a local plan, not published tickets.

Source: the confirmed first-version specification and its 39 acceptance criteria. The repository now contains an iOS implementation; acceptance checks remain pending.

## Proposed Destination

Use local files to continue the existing local documentation workflow. No issue tracker or triage configuration was found. If an external tracker is wanted, run `/setup-matt-pocock-skills` to configure it first.

After approval, create one file per ticket under `.scratch/voice-expense-tracker/issues/`, numbered in dependency order, with explicit Blocked by entries and ready-for-agent status. That status describes ticket readiness after dependencies are satisfied; it does not authorize implementation in this conversation.

## Ticket Breakdown

### 01: Record an expense by keyboard offline

**Blocked by:** None.

**What it delivers:** On the iPhone, complete an amount, description, payment source/channel, and date form; save locally offline; see the expense in date-grouped history and receive a truthful foreground save summary. Include the minimum runnable app and persistent storage in this working user journey.

**Acceptance coverage:** CAP-07, CAP-16, HIS-01. Supply initial selectable payment choices without requiring a full settings feature. Invalid/incomplete form data cannot become a saved expense. Reopening the app preserves saved records. Failure must not display Saved.

### 02: Manage consistent payment sources

**Blocked by:** 01 — Record an expense by keyboard offline.

**What it delivers:** Manage payment sources, use them in entry, resolve known aliases to existing sources, and ask before adding an unfamiliar source. Keep channel and source distinct while displaying a combined payment method.

**Acceptance coverage:** CAP-08 through observable source-management and expense-entry behavior. Voice entry will reuse these rules in tickets 05 and 06.

### 03: Correct or remove a saved expense

**Blocked by:** 01 — Record an expense by keyboard offline.

**What it delivers:** Edit records from history or the save confirmation, delete records, and Undo a new save. Persist the result, including changed expense dates and grouping.

**Acceptance coverage:** Local portions of HIS-02 and HIS-03; Edit and Undo portions of CAP-17. Remote propagation is completed by ticket 12.

### 04: Review monthly and yearly totals

**Blocked by:** 03 — Correct or remove a saved expense.

**What it delivers:** Select a month/year in the same app and see accurate local totals that react to saving, editing, date moves, deletion, and Undo, without internet.

**Acceptance coverage:** SUM-01 through SUM-06. Exclude drafts when ticket 06 introduces them; ticket 06 verifies that integration. Ticket 11 verifies pending-upload expenses remain counted. Do not add charts or budgets.

### 05: Save a complete expense by voice

**Blocked by:** 02 — Manage consistent payment sources.

**What it delivers:** Start voice entry from the app, speak a complete Indonesian, English, or mixed-language purchase, and see one correctly saved expense. Support short-silence completion, Done, Cancel, keyboard switching, combined items, and relative dates. Choose and document the online interpretation approach and its retention constraints within this working journey.

**Acceptance coverage:** CAP-02, CAP-05, CAP-06, CAP-13, CAP-15, CAP-18; voice reuse of CAP-07 and CAP-08. Retain no permanent audio/transcript archive. Incomplete or ambiguous input must not auto-save; conversational completion follows in ticket 06. Verify microphone permission behavior on a device.

### 06: Finish unclear voice expenses and recover failed interpretation

**Blocked by:** 05 — Save a complete expense by voice.

**What it delivers:** Ask for missing/ambiguous information, accept follow-up speech into the same capture, and save once complete. Preserve captured text as an editable, retryable draft when interpretation fails. Confirm unfamiliar payment sources through the same flow.

**Acceptance coverage:** CAP-03, CAP-04, CAP-12; conversational part of CAP-08. Drafts never appear as spending in history totals; verify SUM-03 against whichever summary functionality is available, without making summaries a prerequisite for capture.

### 07: Launch voice with Back Tap without duplicate capture

**Blocked by:** 06 — Finish unclear voice expenses and recover failed interpretation.

**What it delivers:** Configure a Back Tap shortcut on the actual iPhone; launch a fresh voice capture even after using keyboard mode. Repeated activation while listening, clarifying, or saving returns to the existing capture. Uncertain save retries create at most one expense.

**Acceptance coverage:** CAP-01, CAP-09, CAP-10. Unlocking is acceptable. Validate device/OS compatibility and instructions; do not intercept volume buttons.

### 08: Resume safely after a capture interruption

**Blocked by:** 07 — Launch voice with Back Tap without duplicate capture.

**What it delivers:** A call or app switch stops listening and preserves captured text. The next shortcut activation offers Resume draft or Start new without automatically restarting the microphone. Explicit Cancel discards the capture.

**Acceptance coverage:** CAP-14 and interrupted-flow CAP-15, with CAP-12 draft behavior. Validate on the actual iPhone.

### 09: Confirm potentially repeated purchases

**Blocked by:** 05 — Save a complete expense by voice.

**What it delivers:** Across voice and keyboard entry, a fresh capture matching a just-saved amount, description, and source within two minutes asks whether another expense is intended. Allow intentional repeat purchases and prevent an unwanted second save.

**Acceptance coverage:** CAP-11. This is separate from active-capture reuse in ticket 07.

### 10: Show private save notifications

**Blocked by:** 03 — Correct or remove a saved expense; 05 — Save a complete expense by voice.

**What it delivers:** After successful local storage, show a foreground summary with Edit and Undo or an appropriate permitted background notification. Default lock-screen content is generic. Saving remains usable if notifications are denied.

**Acceptance coverage:** CAP-16 and CAP-17 across voice/keyboard paths. Test permission states and device notification presentation. Do not imply Google upload success in a local-save confirmation.

### 11: Upload expenses reliably into yearly Google Sheets

**Blocked by:** 01 — Record an expense by keyboard offline.

**What it delivers:** Authorize Google, save locally, and automatically upload new expenses directly into a reused Expense Tracker — YYYY spreadsheet and numbered monthly tabs. Route by expense date, show local/pending/uploaded states, and reconcile retries without duplicate rows, including a lost successful response.

**Acceptance coverage:** GSH-01 through GSH-07, plus GSH-11 and GSH-12 scope boundaries. Verify a real spreadsheet and controlled failures. No intermediate Excel file. Local saved expenses remain counted while pending upload; verify SUM-03 if the summary exists. Do not implement Sheets-to-app edits or restore.

### 12: Keep Google Sheets aligned with app corrections

**Blocked by:** 03 — Correct or remove a saved expense; 11 — Upload expenses reliably into yearly Google Sheets.

**What it delivers:** Propagate edits, deletion, and Undo, including changes racing with a queued or in-flight upload. Date edits move rows across month/year destinations, leaving one current row or no row after removal. Retry interrupted work until reconciled.

**Acceptance coverage:** GSH-08, GSH-09, GSH-10; complete remote portions of HIS-02 and HIS-03. Do not import direct spreadsheet edits.

## Delivery and Verification Rules

- Every ticket includes user-visible behavior, the required persistence/integration changes, and suitable behavioral checks. Do not split tickets into UI-only, storage-only, or test-only layers.
- Each ticket demonstrates its own narrow journey. No standalone final testing ticket substitutes for verification within each slice.
- Criterion overlap is intentional where a later ticket completes an integration. At final comparison, evaluate every criterion against the combined app.
- Dependencies express genuine prerequisites rather than a mandatory linear sequence. For example, Sheets upload does not require voice capture or summaries.
- Product exclusions remain unchanged. A technical blocker or an unverified platform behavior must be recorded rather than silently changing the specification.

## Remaining Planning Decisions

Tickets 01–06 are authorized for implementation. See [tickets 01–03](verification-01-03.md), [04](verification-04.md), [05](verification-05.md), and [06](verification-06.md) for checks and platform limitations. Tickets 07–12 still require implementation authorization. No external issues have been published. Code and behavioral tests do not establish acceptance until they are run on macOS and the required device checks are performed.

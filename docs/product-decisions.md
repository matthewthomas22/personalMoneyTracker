# Voice Expense Tracker: Product Decisions

## Confirmed on 2026-10-20

- The first version is for personal use, with expenses stored on the user's iPhone.
- Capture accepts Indonesian, English, and a mixture of both.
- Rupiah is the first version's only currency.
- If a payment method is missing, ask for it and accept a spoken answer.
- Save automatically when all required information is available and unambiguous.
- Show the saved result with Edit and Undo actions.
- Clarify missing or ambiguous information before saving.
- Each expense presents an amount, description, and payment method.
- Use Back Tap to invoke a shortcut as the first launch method. Unlocking before capture is acceptable.
- Online processing of spoken expense input is allowed; a provider has not been selected.
- Distinguish payment channel (such as QRIS) from payment source (such as GoPay or SeaBank), while displaying them together as the payment method.
- Default each expense to its capture date and time.
- Provide a history list grouped by date, with editing and deletion.
- Begin voice capture when launched through the shortcut. Process after a short silence, with Done and Cancel controls available.
- A spoken follow-up completes the same expense capture.
- Combine multiple items into one expense when they clearly belong to one purchase with one payment method; sum explicit item amounts and describe all items. Clarify unclear totals or payments.
- Maintain a user-managed list of payment sources. Ask before adding an unfamiliar source and recognize aliases for existing sources.
- If processing fails after text was captured, preserve an unfinished draft with Retry and manual editing. Drafts do not count as spending.
- If speech recognition produces no text, offer typing or recording again.
- Resolve explicit relative purchase dates using the iPhone's local date and time. Default to the capture date when no date is spoken; clarify ambiguous dates.
- While listening, clarifying, or saving, repeated shortcut activation returns to the same capture without another recording or save. Retrying a save creates at most one expense.
- A new capture matching a just-saved expense's amount, description, and payment source within two minutes asks whether to save another. Legitimate repeated purchases remain possible.
- Show Saved only after successful storage. The confirmation includes the expense amount, description, and payment method.
- While the app is open, show an in-app save confirmation with Edit and Undo. In the background, use a system notification if permitted. Default lock-screen previews to a generic Expense saved message.
- An interruption stops listening and preserves captured text as a draft. The next shortcut activation offers Resume draft or Start new. Do not automatically resume microphone recording after an interruption.
- Explicit Cancel discards the current capture.
- Provide keyboard input as a full alternative to speech, available from the capture screen and when speaking is impractical.
- Every fresh Back Tap capture defaults to voice mode, regardless of the last-used input mode. A visible control switches to keyboard input. Existing capture and draft handling still apply.
- Manual entry provides Amount, Description, Payment source, Payment channel, and Date, with an explicit Save button. Date defaults to today; payment selections use saved lists. Complete manual entries can save offline.
- Discard captured audio after processing; retain expense fields. Captured text is kept only while needed for a draft or correction. Permanent transcripts and audio playback are outside version one. Remote processor retention remains to be verified when choosing a provider.
- Use direct Google Sheets integration as the primary spreadsheet option, without generating an intermediate Excel export file.
- Save expenses on the phone first, then upload automatically when connected. Distinguish Saved on phone, Pending upload, and Added to Google Sheets statuses.
- Organize Google Sheets as one spreadsheet per expense year, named Expense Tracker — YYYY, with monthly tabs named 01 January through 12 December. Create a monthly tab when its first expense is uploaded; reuse the linked yearly spreadsheet.
- Route expenses by expense date, not upload or capture date. A date edit moves the remote row to the appropriate monthly tab and yearly spreadsheet.
- The app is the primary place to add, edit, and delete expenses. Propagate those changes to Google Sheets. Changes made directly in Sheets do not update the app in version one.
- Keep the first version simple. A Summary screen in the same app shows a selected month's total and that year's total, with month and year selection. Charts and budgets are outside version one.
- Calculate summaries from saved local expenses, including those pending Google Sheets upload. Exclude drafts and update totals after edits, deletion, or Undo.
- Defer restoring app history from Google Sheets. Automatic uploads and spreadsheet history remain included, but reinstalling the app does not reload that history in version one.

## Implementation follow-ups

These do not expand the agreed first-version product scope. Validate platform behavior and choose implementation details before relying on them.

- Launch and capture
  - Confirm Back Tap compatibility on the user's device before implementation validation.
  - Voice capture permissions and device validation.
- Voice interpretation
  - Online processing provider and its retention policy.
  - Apply the agreed clarification rule to ambiguous spoken corrections.
- Expense model
  - Configure the user's payment sources and channels through the agreed editable list; recognize aliases without silently adding unfamiliar sources.
- Expense history
  - Retry reconciliation for Google Sheets uploads.
  - Implement propagation of edits and deletion; restore from Sheets is explicitly deferred.

## Platform evidence

- Apple's App Review Guidelines section 2.5.9 prohibit changing standard Volume Up/Down behavior. A global volume-down launcher is not a supported product assumption.
  https://developer.apple.com/app-store/review/guidelines/
- An Action button can invoke an App Shortcut.
  https://developer.apple.com/design/human-interface-guidelines/action-button
- Back Tap can invoke a shortcut.
  https://support.apple.com/en-ie/guide/shortcuts/apd897693606/ios
- A shortcut that opens an app through Siri requires unlocking. The complete microphone capture flow while locked remains unverified and requires a device prototype if needed.
  https://support.apple.com/en-gb/guide/shortcuts/apd07c25bb38/ios

## Status

Product scope confirmed by the user on October 20, 2026. The local specification is indexed by docs/mvp-spec.md and split under docs/specs, including acceptance criteria for later app comparison. The user explicitly requested no implementation yet. No application code has been created.

## Spreadsheet integration evidence

- Google Sign-In for iOS supports consent and access tokens for Google API access; the Sheets API can append rows directly, without an intermediate spreadsheet file.
  https://developers.google.com/identity/sign-in/ios/api-access
  https://developers.google.com/workspace/sheets/api/reference/rest/v4/spreadsheets.values/append
- Google Sheets on iPhone/iPad supports opening XLS/XLSX files. Temporary XLSX sharing is an alternative, subject to validating the installed share destinations on a device.
  https://support.google.com/docs/answer/6000292?co=GENIE.Platform%3DiOS&hl=en
  https://developer.apple.com/documentation/uikit/collaborating-and-sharing-copies-of-your-data
- A temporary export can be removed by the app once no longer needed, but the app cannot guarantee that iOS or the receiving app retains no copy.
  https://developer.apple.com/documentation/foundation/using-the-file-system-effectively
- Design implication: a readable spreadsheet export is not a full recovery mechanism unless stable identifiers, dates, payment fields, settings, and an import flow are explicitly covered.

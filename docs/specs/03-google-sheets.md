# Google Sheets Integration

## Confirmed Behavior

- Connect with the user's Google authorization. Upload directly without an intermediate Excel file.
- Save locally first, then upload automatically when connected. Distinguish Saved on phone, Pending upload, and Added to Google Sheets.
- Use one linked spreadsheet per expense year, named Expense Tracker — YYYY.
- Use tabs named 01 January through 12 December, created when their first expense needs uploading. Reuse linked files and tabs across uploads and retries.
- Route by expense date, not entry/upload date.
- Propagate app additions, edits, deletion, and Undo. Date changes can move a row between tabs or yearly spreadsheets.
- Reconcile uncertain outcomes and retries without duplicate rows.
- The app is authoritative; direct Sheets edits do not update the app.
- Recovery from Sheets, including after reinstalling the app, is deferred.

## Acceptance Criteria

| ID | Scenario | Expected result |
|---|---|---|
| GSH-01 | Authorize Google access and save while connected | Save locally, then upload directly without generating an Excel export. |
| GSH-02 | Save offline and reconnect | Keep the expense and local totals, show pending status, then upload when connected. |
| GSH-03 | Local save succeeds but upload fails | Report local success without claiming Sheets success; retain for retry. |
| GSH-04 | First and second October 2026 uploads | Use and reuse Expense Tracker — 2026 / 10 October. |
| GSH-05 | First November 2026 upload | Add or reuse 11 November in the same yearly spreadsheet. |
| GSH-06 | Record December 31, 2026 spending on January 2, 2027 | Route to Expense Tracker — 2026 / 12 December. |
| GSH-07 | Remote write succeeds but response is lost, followed by retry | Eventually reconcile to one remote row per logical expense. |
| GSH-08 | Edit an uploaded expense | Update its representation without a second logical expense row. |
| GSH-09 | Change date across a month/year boundary | Eventually leave one row in the correct destination with no obsolete original row. |
| GSH-10 | Delete or Undo before, during, or after upload | Eventually leave no remote row for the removed local expense. |
| GSH-11 | Edit cells directly in Sheets | Do not import those changes or imply two-way synchronization. |
| GSH-12 | Reinstall the app | Do not promise restoration of prior history from Sheets. |

## Validation Notes

Use controlled failures and a dedicated real Google spreadsheet. Inspect row counts and values after retries, edits, moves, and deletion. Exact columns, identity metadata, scopes, scheduling, and handling externally damaged spreadsheets remain technical choices. File name alone is not a reliable linked-spreadsheet identity.

Validate background scheduling on iOS. Eventual synchronization requires the app to be able to run and have connectivity and authorization; unrestricted continuous background execution is not promised.

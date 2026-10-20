# Tickets 01–03 verification

Implementation authorized by the user on October 20, 2026, for tickets 01–03 only. Earlier documentation statements that implementation is not authorized describe the preceding planning phase.

## Build and automated checks

On a Mac with Xcode and XcodeGen:

```sh
xcodegen generate
xcodebuild -list -project ExpenseTracker.xcodeproj
xcrun simctl list devices available
xcodebuild test -project ExpenseTracker.xcodeproj -scheme ExpenseTracker -destination 'platform=iOS Simulator,name=<installed simulator name>'
```

Replace the simulator placeholder with a name from the available device list. Test sources are under `ExpenseTrackerTests/`.

This Windows environment has no Swift, Xcode, XcodeGen, simulator, or connected iPhone. Automated Swift tests, compilation, and the following device checks are **not executed** here. The user explicitly deferred Xcode checks to their MacBook. Source review alone does not establish acceptance criteria as passed.

## Ticket 01: keyboard entry offline

- Enable Airplane Mode. Enter Rp15000, a description, source, channel, and today's date. Save. Check one history record and a Saved on phone confirmation with the correct fields.
- Save another purchase on a different date. Check date grouping and the combined channel/source presentation.
- Close and reopen the app. Check that both records remain.
- Attempt empty fields, zero, negative, fractional, malformed, and overflowing amounts. None may become a saved expense.
- Run the failing-persistence automated checks. A failed write must preserve the previous in-memory state and must not produce a success confirmation.

Coverage: CAP-07, CAP-16, HIS-01.

## Ticket 02: payment sources

- Create a source, rename it, and add an alias. Close and reopen; check persistence.
- In expense entry, use an alias with different letter case or surrounding whitespace. Check that it selects the existing source without creating another.
- Enter an unfamiliar source. Cancel its addition; check that no source is created. Repeat and explicitly confirm; check that exactly one source is added and selectable.
- Attempt a name or alias already assigned to another source. Check that the conflict is rejected.
- Save an expense against a source, then archive/remove that source. Check that the original expense retains its payment identity and that inactive sources are not offered for new expenses. Check correction of that historical expense.

Coverage: keyboard/source-management portion of CAP-08. Spoken clarification remains deferred to tickets 05–06.

## Ticket 03: correct or remove an expense

- Open an expense from history, change its fields, and save. Check the updated record after reopening.
- Change December 31, 2026 to January 1, 2027. Check that the record moves to the correct date group and the empty old group disappears.
- Save a new expense and use Edit in its confirmation. Check that the same record is updated.
- Save another expense and use Undo. Check that only that expense is removed, including after reopening.
- Delete an expense from history. Check persistence after reopening.
- Exercise failed writes for update and deletion. Check that the stored record and visible history remain unchanged and an error is shown.

Coverage: local HIS-02/HIS-03 and foreground Edit/Undo portions of CAP-17. Sheets propagation and background notifications remain deferred.

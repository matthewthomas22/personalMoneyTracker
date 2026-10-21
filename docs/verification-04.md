# Ticket 04 verification

Implementation adds a Summary tab with month and year selection, the selected month's total, and the selected year's total. It reads only `ExpenseStore.expenses`, so saved local records are counted regardless of any future upload state. Voice drafts live outside this collection and are excluded. Totals recalculate from the observed store after successful saves and corrections. Reporting uses Gregorian expense dates in the device's current time zone. Values that exceed the `Int64` currency limit display an explicit error instead of overflowing or displaying a false total.

## Automated checks on a Mac

The development environment is Windows and has no Swift executable, Xcode, or iOS simulator. Neither these new tests nor the existing tickets 01–03 tests have been executed here. Mac compilation and device verification remain outstanding.

From the repository root on the Mac:

```sh
xcodegen generate
xcodebuild -list -project ExpenseTracker.xcodeproj
xcrun simctl list devices available
xcodebuild test -project ExpenseTracker.xcodeproj -scheme ExpenseTracker -destination 'platform=iOS Simulator,name=<available iPhone simulator>'
```

Replace the simulator placeholder with a device from the previous command. Run the complete test suite, including tickets 01–03. `ExpenseSummaryTests` covers selected periods, empty periods, local midnight/year boundaries, durable save/edit/date move/delete/Undo effects, failed writes, and overflow. Those checks have been authored but are not validated until the Mac run succeeds.

## App acceptance checks

1. First complete the checks in `verification-01-03.md`; earlier platform validation remains pending.
2. In airplane mode, save Rp15.000 and Rp10.000 dated October 2026. Select October and 2026 in Summary. Expect Rp25.000 for both totals.
3. Save Rp30.000 dated November 2026. Select November; expect Rp30.000 monthly and Rp55.000 yearly. Select an empty month; expect Rp0 monthly.
4. Edit the Rp15.000 expense to Rp20.000 and inspect Summary again. October becomes Rp30.000 and the year Rp60.000. Delete Rp10.000; October becomes Rp20.000 and the year Rp50.000.
5. Move the remaining October expense to January 2027. October 2026 becomes Rp0, 2026 becomes Rp30.000, and January/2027 each become Rp20.000. Reopen the app and confirm these values remain.
6. Save another expense, use Undo save, then inspect its month and year. Its contribution must disappear.
7. Leave an incomplete or failed voice capture as a draft using ticket 06's flow. Summary must remain unchanged; completing that capture contributes exactly once. Ticket 11 will verify saved pending-upload records remain counted when uploads exist.
8. Use VoiceOver and a small iPhone screen to verify both totals and month/year controls remain readable and operable.

No charts, budgets, upload dates, or network requests are involved in summary calculations. Changing the device time zone can change the reporting period of an expense near midnight; this is consistent with local expense-day grouping.

# Personal Money Tracker

A native iPhone expense tracker. This implementation covers tickets **01–06** in [the ticket plan](docs/ticket-plan.md): offline keyboard entry, payment sources, local corrections, monthly/yearly totals, voice entry, and clarification with retryable drafts.

## Run on an iPhone

Use a Mac with Xcode and XcodeGen installed. From the repository root:

```sh
xcodegen generate
open ExpenseTracker.xcodeproj
```

Select the ExpenseTracker scheme and your iPhone or an iOS simulator. For a physical device, select your development team in Signing & Capabilities and choose a unique bundle identifier if required. Build and run. The deployment target and build configuration are defined in `project.yml`.

Expenses and payment sources are stored in the app's local Application Support directory. Saves must reach local storage before the app reports success. No account or network connection is required. Removing the app also removes its local records; backup and restore are not implemented.

## Scope and verification

Open **Summary** to select a month and year. In **Record**, choose **Voice entry** to capture a purchase or continue a draft; keyboard entry remains available offline. Voice recognition uses Apple Speech, with a bounded local grammar for expense interpretation. Unsupported or ambiguous phrasing needs clarification or manual correction. See [voice verification and privacy notes](docs/verification-05.md) for supported phrasing, online processing, and limitations.

Tickets 07–12 remain deferred: Back Tap shortcuts, full interruption recovery, duplicate-purchase prompts, background notifications, and Google Sheets synchronization.

See [tickets 01–03 verification](docs/verification-01-03.md), [ticket 04](docs/verification-04.md), [ticket 05](docs/verification-05.md), and [ticket 06](docs/verification-06.md) for automated and device checks. The shared Xcode test scheme includes all test files. Development took place on Windows without Swift, Xcode, or an iPhone simulator. Earlier tickets also remain unverified on your MacBook; run the full suite and device checks before treating this build as validated.

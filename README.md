# Personal Money Tracker

A native iPhone expense tracker. This implementation covers tickets **01–03** in [the ticket plan](docs/ticket-plan.md): offline keyboard entry, payment source management, and local expense corrections.

## Run on an iPhone

Use a Mac with Xcode and XcodeGen installed. From the repository root:

```sh
xcodegen generate
open ExpenseTracker.xcodeproj
```

Select the ExpenseTracker scheme and your iPhone or an iOS simulator. For a physical device, select your development team in Signing & Capabilities and choose a unique bundle identifier if required. Build and run. The deployment target and build configuration are defined in `project.yml`.

Expenses and payment sources are stored in the app's local Application Support directory. Saves must reach local storage before the app reports success. No account or network connection is required. Removing the app also removes its local records; backup and restore are not implemented.

## Scope and verification

Tickets 04–12 remain deferred: summaries, voice capture, shortcuts, notifications, duplicate-purchase prompts, and Google Sheets synchronization are not implemented.

See [verification instructions](docs/verification-01-03.md) for the automated test command and device acceptance checks. Development took place on Windows without Xcode or an iPhone simulator; iOS compilation and device checks must be run on a Mac before treating this build as validated.

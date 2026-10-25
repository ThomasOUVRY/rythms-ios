# Rhythms

[![CI](https://github.com/ThomasOUVRY/rythms-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/ThomasOUVRY/rythms-ios/actions/workflows/ci.yml)

Calm countdowns for recurring things — no streaks, no scores. Designed with ADHD in mind: time stays visible, nudges are actionable, and nothing shames you for missing one.

Two kinds of rhythm:

- **Since last time** (e.g. brush teeth every 8–9 h). Refills when you tap its button, drains toward a soft floor (12%) and waits there. It never runs dry.
- **Repeating period** (e.g. surprise her every 2 weeks, run every 3 days). Fixed calendar periods. It runs empty, then a fresh period starts on its own, with a short "reset moment" the next time you open the app.

## What's in it

| Area | Where |
|---|---|
| Home, detail, editor, reminders, settings, reset moment | `App/Views/` |
| Data model (SwiftData) and templates | `Shared/Model/` |
| Countdown maths (fill, windows, periods) | `Shared/Engine/RhythmEngine.swift` |
| Button-label suggestions ("Brush teeth" → "Brushed") | `Shared/Engine/LabelSuggester.swift` |
| Reminder planning (checkpoints, follow-ups, quiet hours, pause) | `Shared/Notifications/ReminderPlanner.swift` |
| Notification wording (varied, guilt-free) | `Shared/Notifications/NudgeCopy.swift` |
| Notifications with action buttons | `Shared/Notifications/NotificationScheduler.swift`, `App/AppDelegate.swift` |
| Home Screen + Lock Screen widgets, Lock Screen Live Activity | `Widgets/` |
| Unit tests for the engine and planner | `Tests/` |

Requires **iOS 17** or later (works on iPhone 12). The Live Activity is a Lock Screen countdown; there is no Dynamic Island design.

## Building it (needs a Mac)

iOS apps can only be built with Xcode on macOS. The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen), so it isn't checked in.

1. On a Mac with Xcode 15 or later, install XcodeGen:
   ```bash
   brew install xcodegen
   ```
2. In `project.yml`, set your own values:
   - `BUNDLE_ID_PREFIX`, e.g. `com.yourname.rhythms`
   - `APP_GROUP`, e.g. `group.com.yourname.rhythms` (must start with `group.`)
   - `DEVELOPMENT_TEAM`: your Apple team ID (Xcode → Settings → Accounts)
3. Generate and open the project:
   ```bash
   xcodegen generate
   ```
   ```bash
   open Rhythms.xcodeproj
   ```
4. Pick your iPhone, press Run. For the tests: Product → Test (⌘U).

The App Group is how the widgets see your rhythms. Without it the app still runs, but widgets stay empty.

### Without a Mac

Every push to `main` runs [`.github/workflows/ci.yml`](.github/workflows/ci.yml) on a GitHub macOS runner: it generates the project, builds the app and widgets for the iOS Simulator (no signing needed) and runs the tests. Results and the full build log are attached to each run.

## How reminders work

Each rhythm has its own reminder settings:

- **Nudge style**: one quiet nudge, or a nudge plus one time-sensitive follow-up an hour later (then it stops), or a live Lock Screen countdown while it's due.
- **Moment**: when the window opens, a set time, or a routine moment (wake up, after dinner, before bed, when I get home).
- **Checkpoints** for periods: small steps like "Day 1: pick an idea", "Day 8: anything to buy?".

Every notification has the rhythm's own button ("Brushed") plus snoozes ("In 20 minutes", "When I get home"), so you never have to open the app. App-wide settings cover routine times, quiet hours, varied wording, a "rough day" pause, and your home location.

### Known limits

- iOS has no background timer, so reminders are planned ahead and re-planned whenever the app opens, a widget button is tapped, or a notification button is used. A since-last rhythm gets its nudge and follow-up, then waits for you.
- "When I get home" needs location permission. It's armed only while a rhythm is due, at the moment the plan is refreshed.
- iOS only lets the app *start* a Live Activity while it's open, so the Lock Screen countdown appears after the app has been opened during the due stretch.
- The time-sensitive follow-up needs the Time Sensitive Notifications capability on your Apple developer account. Without it, the follow-up arrives as a normal notification.
- App icon artwork isn't included yet (`App/Resources/Assets.xcassets/AppIcon.appiconset`).

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

### Installing on an iPhone from Windows (free)

[`.github/workflows/ipa.yml`](.github/workflows/ipa.yml) builds an **unsigned IPA** on every push to `main` (or from Actions → "Build unsigned IPA" → Run workflow).

1. On GitHub, open Actions → the latest "Build unsigned IPA" run → download **Rhythms-unsigned-ipa** at the bottom, and unzip it to get `Rhythms-unsigned.ipa`.
2. Install **iTunes** and **iCloud** from apple.com (not the Microsoft Store versions), then **Sideloadly** from sideloadly.io.
3. Plug in the iPhone, unlock it and tap **Trust**.
4. Drag the IPA into Sideloadly, enter your Apple ID, click **Start**.
5. On the iPhone: turn on Settings → Privacy & Security → **Developer Mode** (restart), then Settings → General → VPN & Device Management → trust your Apple ID.

With a free Apple ID the app must be re-signed every 7 days (Sideloadly can auto-refresh over Wi-Fi while the PC is on). Free signing may not grant App Groups, in which case widgets show "Add a countdown in the app"; the app itself works.

## Widgets

| Widget | Sizes | Shows |
|---|---|---|
| Next up | Home small, Lock Screen wide, Lock Screen inline | The rhythm that needs you soonest, with its button on the Home Screen |
| Habit rings | Home small, Lock Screen round | Rings for the habits you pick: up to 4 on the Home Screen, 1 on the Lock Screen (Touch and hold → Edit Widget → Habits). Empty choice = the ones that need you soonest |
| All rhythms | Home medium | Your first three rhythms side by side |
| Live countdown | Lock Screen | While a rhythm set to "Live countdown" is due, with its button |

Widgets read your rhythms through the App Group. If they show "Add a countdown in the app" while you have rhythms, the App Group isn't active in your signed build.

## How reminders work

Each rhythm has its own reminder settings:

- **Nudge style**: one quiet nudge, or a nudge plus one follow-up an hour later (then it stops), or a live Lock Screen countdown while it's due.
- **Moment**: when the window opens, a set time, or a routine moment (wake up, after dinner, before bed, when I get home).
- **Checkpoints** for periods: small steps like "Day 1: pick an idea", "Day 8: anything to buy?".

Every notification has the rhythm's own button ("Brushed") plus snoozes ("In 20 minutes", "When I get home"), so you never have to open the app. App-wide settings cover routine times, quiet hours, varied wording, a "rough day" pause, and your home location.

### Known limits

- iOS has no background timer, so reminders are planned ahead and re-planned whenever the app opens, a widget button is tapped, or a notification button is used. A since-last rhythm gets its nudge and follow-up, then waits for you.
- "When I get home" needs location permission. It's armed only while a rhythm is due, at the moment the plan is refreshed.
- iOS only lets the app *start* a Live Activity while it's open, so the Lock Screen countdown appears after the app has been opened during the due stretch.
- The app doesn't use Time Sensitive notifications (a paid-account entitlement), so a Focus mode or Scheduled Summary can hold nudges back. Allow Rhythms in each Focus (Settings → Focus → Apps) and leave it out of Scheduled Summary; the app's Settings screen shows these steps.
- App icon artwork isn't included yet (`App/Resources/Assets.xcassets/AppIcon.appiconset`).

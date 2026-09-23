# Dr Jay

Sleep + water accountability app for iPhone (iOS 26+). Checks in three times
a day (morning / afternoon / night): did you get 6–9 hours of sleep, and are
you hitting your water goal? If not, an on-device LLM — in the voice of a
certain sarcastic diagnostician — roasts you. If you're on track, it (grudgingly)
approves.

## Stack

- SwiftUI + SwiftData (App Group–backed store for history/streaks)
- **FoundationModels** (Apple Intelligence, on-device) generates the actual
  roast/hype line, in a House-M.D.-style persona with three intensity levels
  (gentle / playful / spicy) — with a curated local fallback bank if Apple
  Intelligence isn't available on the device/region. See `Shared/RoastEngine.swift`.
- Sleep has a guard rail both ways: under 6h *and* over 9h both get roasted,
  just differently (`GoalCalculator.SleepStatus`).
- Local check-in notifications contain plain status/progress from the latest
  snapshot. They are rescheduled whenever the app refreshes or data changes;
  the AI roast line stays in-app where there's room for it.
- **ActivityKit** Live Activity (Dynamic Island + Lock Screen): live sleep/water
  rings plus a Cleared/Flagged status per kind, no long text to get cut off.
- **WidgetKit** home screen + lock screen widgets — same progress-only design.
- **App Intents** for Siri: "Log a bottle to Dr Jay", "Log 1 hour of sleep to
  Dr Jay" (bounded 15-min-to-12h duration picker so the amount can be spoken
  in one phrase), plus status-check intents. See `Roastie/AppIntents/`.
- HealthKit (read-only) to pull last night's sleep automatically, with a
  manual add-sleep flow (additive, logged any time) as a fallback.
- On-device JSON backup/export/import (Settings → Data), plus a reminder
  notification the day before a free (non-paid) developer signing profile's
  7-day trust window expires.

## Setup

1. Install **Xcode** (26+ SDK) and `brew install xcodegen` if you don't
   already have it.
2. Set your Apple Developer Team ID as an environment variable, then generate
   the Xcode project (it's gitignored — regenerate it locally rather than
   committing a project file with someone else's signing details baked in):
   ```
   DEVELOPMENT_TEAM=YOUR_TEAM_ID xcodegen generate
   ```
   Re-run this any time you add/remove files, since the `.xcodeproj` is
   generated from `project.yml`, not hand-edited.
3. Open `Roastie.xcodeproj`. Bundle IDs are `dev.jeyanth.roastie` (+
   `.widgets`) — change `bundleIdPrefix` in
   `project.yml` for your own, then re-run `xcodegen generate`.
4. Confirm the **App Groups** capability is picked up in each target's
   Signing & Capabilities tab, using `group.dev.jeyanth.roastie` (must match
   across both targets — already set in `project.yml`; update it
   alongside the bundle ID prefix if you change that).
5. Build & run the `Roastie` scheme on a real device. Live Activities,
   Foundation Models, and App Intents all need a real device or a Simulator
   with Apple Intelligence enabled (Settings → Apple Intelligence & Siri) —
   Foundation Models silently falls back to the local line bank otherwise, so
   the app still works either way.

## Known caveats

- Local notification text reflects the most recent snapshot available when
  the app scheduled it. iOS doesn't launch app code at local-notification
  delivery time, so HealthKit changes made while the app remains closed won't
  appear until the next app or background refresh.
- `BGProcessingTaskRequest` timing is opportunistic (iOS decides when it
  actually runs) — it's a backstop for day-rollover, not the primary
  mechanism. The app also refreshes on every foreground.
- A free (non-paid) Apple Developer account's signing trust expires 7 days
  after install; export a backup in Settings before that happens if you're
  not on a paid account, and import it after reinstalling.
- Default goals: sleep 6–9h, water 4 bottles/day @ 750ml (both editable in
  Settings).

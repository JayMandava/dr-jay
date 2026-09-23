# Dr Jay

Dr Jay is a private, on-device accountability app for iPhone (iOS 26+) that
tracks sleep, water, and food—with praise when you deliver and a sharp roast
when you do not.

## What it tracks

- **Sleep:** a healthy range of 6–9 hours. Sleep can be read from HealthKit or
  entered manually. A manual entry remains authoritative for the day unless
  the user explicitly replaces it with Health data.
- **Water:** progress toward a configurable full-day goal. Morning, afternoon,
  and night check-ins judge whether the complete daily goal has been reached;
  they do not estimate whether the user is "on pace."
- **Food:** plain-language meal and snack entries are analyzed on device. An
  unhealthy entry receives an immediate roast, while the Today screen rolls
  all analyzed entries into an order-independent daily score:
  **Good (80–100), Bad (60–79), or Ugly (0–59)**. Individual classifications
  can be corrected or deleted from History. A correction becomes private
  local memory: exact future matches use it automatically, while similar
  foods receive it only as context for a fresh assessment.

The Today screen keeps the current verdict concise. History contains the
detailed daily record, food entries, corrections, and previous check-ins.
Current and longest streaks count consecutive days on which both sleep and
water goals were completed; food does not currently affect streaks.

## Privacy and resilience

- Health access is read-only.
- Roasts and food analysis use Apple's Foundation Models on device; food logs
  and health data are not sent to a server.
- Sleep and water roasts use a curated local fallback bank when Apple
  Intelligence is unavailable. Food remains logged but unscored until its
  on-device analysis succeeds.
- App data is stored locally with SwiftData in the shared App Group container.
- JSON export/import in **Settings → Data** preserves sleep, water, food
  entries, scores, learned food corrections, and check-in history; streaks are
  rebuilt from those daily logs after import. Version 1–4 backups remain
  compatible and manual food corrections are recovered where possible. A
  backup leaves the app only when the user chooses to share the exported file.

## Platform features

- **SwiftUI + SwiftData** for the app and App Group-backed history.
- **FoundationModels** for on-device food analysis and Dr Jay's generated
  roast or approval copy, with gentle, playful, and spicy intensity levels.
- **HealthKit** for read-only sleep import.
- **ActivityKit** for sleep and water progress on the Dynamic Island and Lock
  Screen.
- **WidgetKit** for sleep and water Home Screen and Lock Screen widgets.
- **App Intents** for logging bottles or sleep and checking current status
  through Siri.
- Configurable morning, afternoon, and night local notifications. Their plain
  status text reflects the most recent app snapshot available when scheduled.

## Setup

1. Install Xcode with the iOS 26+ SDK and install XcodeGen if needed:
   `brew install xcodegen`.
2. Generate the Xcode project with your Apple Developer Team ID:

   ```sh
   DEVELOPMENT_TEAM=YOUR_TEAM_ID xcodegen generate
   ```

   `Roastie.xcodeproj` is generated from `project.yml` and intentionally
   gitignored. Regenerate it after adding or removing source files.
3. Open `Roastie.xcodeproj`. The default bundle IDs are
   `dev.jeyanth.roastie` and `dev.jeyanth.roastie.widgets`. Change
   `bundleIdPrefix` and the matching App Group in `project.yml` for another
   developer account, then regenerate the project.
4. Confirm both targets use the same App Group entitlement.
5. Build and run the `Roastie` scheme on a real device with Apple Intelligence
   enabled for the complete experience.

## Validation

The project includes unit coverage for goal calculation, streaks, check-in
window selection, snapshot migration, backup import, and food scoring. Compile
the app and test bundle with:

```sh
xcodebuild -project Roastie.xcodeproj -scheme Roastie \
  -configuration Debug -destination 'generic/platform=iOS' build-for-testing
```

## Known constraints

- iOS does not run app code when a local notification is delivered. Its text
  therefore uses the latest snapshot from the most recent foreground or
  background refresh.
- Background processing is opportunistic and acts as a day-rollover backstop;
  foreground refresh remains the primary update path.
- A free Apple Developer signing profile normally expires after seven days.
  Export a JSON backup before reinstalling if persistent history matters.
- Default goals are 6–9 hours of sleep and four 750 ml bottles of water; water
  settings are configurable.

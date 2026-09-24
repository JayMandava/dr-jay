# Dr Jay

Dr Jay is a private, on-device accountability app for iPhone (iOS 26+) that
tracks sleep, water, and food, and surfaces today's Health step count—with
praise when you deliver and a sharp roast when you do not.

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
- **Steps:** today's cumulative count is read directly from Health for display
  and the daily report. It is never copied into Dr Jay's database or backup.

## Daily report

The overall score is deterministic and uses these base weights:

- **Food: 35%** — today's fixed food score.
- **Sleep: 30%** — full credit from 6–9 hours, proportionally less below 6,
  and reduced above 9.
- **Water: 30%** — progress toward the complete daily bottle goal, capped at
  full credit.
- **Steps: 5%** — normalized up to a soft 8,000-step ceiling. This is not a
  medical target and has deliberately low influence because a phone may not
  capture every walk.

Missing metrics are excluded and the available weights are proportionally
normalized, so unavailable steps never lower the score. Missing sleep or food
is shown explicitly and marks the report incomplete. Overall scores use
**Good (80–100), Bad (60–79), and Ugly (0–59)**.

The report can be generated on demand from Today. Its score, verdict, and
calculation remain fixed; Apple's on-device model writes only Dr Jay's
commentary. Good receives reluctant clinical approval, Bad roasts the weakest
major factor, and Ugly receives the sharper House-style diagnosis. The model
is instructed not to repeat the visible score, weights, or metric list. A
local verdict-aware fallback is used when Apple Intelligence is unavailable.

At 10 p.m., a local notification delivers the latest deterministic report
available when it was scheduled. The notification does not depend on the
language model running at delivery time.

## Brain Dump

Brain Dump is an ephemeral mindfulness conversation with Dr Jay. Closing the
pane immediately discards every turn; prompts and replies are not persisted,
logged, exported, or included in backups. Deterministic local routing blocks
prompt extraction, medical instructions, vulnerable beliefs, immediate-risk
content, and unrelated task requests before generation.

Apple Intelligence is the default responder. **Settings → Brain Dump** can
optionally download and select Gemma 4 E2B. The 2.59 GB LiteRT-LM artifact is
downloaded in the background, excluded from backups, and activated only after
its exact byte count, file signature, SHA-256 checksum, and LiteRT engine
initialization all succeed. Interrupted transfers retain resumable download
data. The model can be deleted independently without affecting app history.

The Today screen puts logging actions and the actionable food card first,
followed by the read-only Steps card and the manual report action. History
contains the detailed daily record, food entries, corrections, and previous
check-ins. Current and longest streaks count consecutive days on which both
sleep and water goals were completed; food and steps do not affect streaks.

## Privacy and resilience

- Health access is read-only.
- Roasts and food analysis use Apple's Foundation Models on device; food logs
  and health data are not sent to a server.
- Brain Dump inference stays on device with either Apple Intelligence or the
  optional Gemma model. The model file and provider preference are separate
  from the deliberately non-persistent conversation.
- Sleep and water roasts use a curated local fallback bank when Apple
  Intelligence is unavailable. Food remains safely logged as unanalyzed when
  the model is unavailable and can be classified manually from History.
- App data is stored locally with SwiftData in the shared App Group container.
- JSON export/import in **Settings → Data** preserves sleep, water, food
  entries, scores, learned food corrections, and check-in history; streaks are
  rebuilt from those daily logs after import. The current export schema is
  version 5; versions 1–4 remain import-compatible, and older manual food
  corrections are recovered where possible. A backup leaves the app only when
  the user chooses to share the exported file. Step counts and generated daily
  report commentary are intentionally excluded from storage and JSON backups.

## Platform features

- **SwiftUI + SwiftData** for the app and App Group-backed history.
- **FoundationModels** for on-device food analysis and Dr Jay's generated
  roast, approval, and manual daily-report commentary, with gentle, playful,
  and spicy intensity levels.
- **LiteRT-LM** for the optional Gemma 4 E2B Brain Dump responder. Apple
  Intelligence remains the default because Gemma requires roughly 2.59 GB of
  storage and substantially more runtime memory.
- **HealthKit** for read-only sleep import and an ephemeral current-day step
  count, with opportunistic background step refresh.
- **ActivityKit** for sleep and water progress on the Dynamic Island and Lock
  Screen.
- **WidgetKit** for sleep and water Home Screen and Lock Screen widgets.
- **App Intents** for logging bottles or sleep and checking current status
  through Siri.
- Configurable morning, afternoon, and night local notifications, plus an
  exact-time 10 p.m. report. Today is personalized from the latest available
  values; a rolling week of generic fallbacks avoids replaying stale metrics
  if the app receives no refresh.

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
window selection, snapshot migration, backup import, food scoring and boundary
conditions, learned food-memory matching, daily-report weighting, missing-step
handling, Brain Dump safety routing, and Good/Bad/Ugly report boundaries.
Compile the app and test bundle
without executing tests with:

```sh
xcodebuild -project Roastie.xcodeproj -scheme Roastie \
  -configuration Debug -destination 'generic/platform=iOS' build-for-testing
```

## Known constraints

- iOS does not run app code when a local notification is delivered. Its text
  therefore uses the latest values from the most recent foreground or Health
  background refresh. Future generic 10 p.m. fallbacks never repeat stale
  metrics as though they belonged to a new day.
- Background processing is opportunistic and acts as a day-rollover backstop;
  foreground refresh remains the primary update path. Health step observer
  delivery is also opportunistic rather than a real-time pedometer feed.
- A free Apple Developer signing profile normally expires after seven days.
  Export a JSON backup before reinstalling if persistent history matters.
- Default goals are 6–9 hours of sleep and four 750 ml bottles of water; water
  settings are configurable.

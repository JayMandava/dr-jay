# Surroundings Awareness

## Existing standards reviewed

Implementation starts from main `3dcdccf` on local branch
`feature/surroundings-awareness`. The prior cloud Siri checkout is untouched.

Reviewed the Spirits implementation and subsequent corrections before editing:

- `4c0af27`: match existing logging typography, field spacing, themed controls,
  and straightforward copy rather than adding another visual language.
- `cf91ecb`: hidden ledger uses a 92% floating card.
- `7a54c82`: daily report uses the same floating presentation.

This feature reuses Settings' native Form section and Today's `clinicalCard`,
16-point padding, 12-point content spacing, semantic type, and DrJayTheme.
It adds no modal and leaves the corrected sheet presentations unchanged.

## Behavior and boundaries

- `AppSettings.surroundingsAwarenessEnabled` defaults to false, including
  migration from settings without that key.
- Enabling does not request permission or network data. The separate Check
  Weather action explains/uses the previously disclosed location sharing.
- A one-shot foreground CLLocationManager requests kilometer accuracy.
  Coordinates are rounded to 0.1 degree before an ephemeral HTTPS Open-Meteo
  request. No health data, user notes, or app identifier is included.
- Coordinates and weather are not persisted. Cache expires after 30 minutes
  and cannot be reused on a different local calendar day. Requests time out;
  disable cancels them, clears weather, and ignores stale callbacks.
- Suggestions are deterministic and optional. The card reads today's saved
  water goal, logged bottles and bottle size to show what is left, and shows
  a goal-met state at or above the target. It never adds weather-based water.
- Food ideas sit in a collapsed "Food ideas near you" section so the card
  stays short. Three examples come from the weather group (warm or humid,
  cool, wet, mild) and a broad region chosen on device from the rounded
  coordinates (nine regions plus a general fallback). The region is not
  stored or sent anywhere. Region boxes are approximate; a border area may
  get a neighbour's examples. No allergy or diet profile is inferred.
- No disease prevention, medical benefit, fixed extra water, dietary
  restriction, or goal change is claimed. User-specific fluid and dietary
  guidance takes precedence.
- Water is automatic and objective. When weather is checked, the card notes
  how many bottles are left (in memory only). The +1 is awarded when today's
  log reaches the goal after that, and the coordinator re-verifies the log.
  If the goal was already met at the check, there is no water bonus.
- Food is picked per idea. Tapping an idea stores that idea's text on today's
  DailyLog (at most three), so a pick stays checked after a later weather check
  suggests different ideas, and it stays visible under "Followed today" when
  the weather has expired. Each idea earns +1 once per day. Food-safety
  reminders are shown but are not pickable.
- A day can earn at most +4 (water +1, three food ideas +1 each), always
  separate from the score and never a penalty for skipping.
- Core score, verdict, weights, goals, streaks, exposure penalties, model
  prompts, notifications, widgets, and Live Activities are unchanged.
- Backup version 12 includes only the water bonus timestamp and the text of
  the ideas you picked, not location or weather. Older backups decode with no
  bonus (version 11 position picks are dropped), and restored ideas are
  trimmed, distinct, and limited to three.
- Disable hides the feature but preserves any already-earned bonus.
  Reset App Data deletes it with the log.

## Verification

Added XCTest cases for weather branches/boundaries, invalid/stale/future and
previous-day weather, settings migration/round-trip, no permission while off
or merely enabled, cancellation/late callbacks, repeat claims, persistence
across reopening the store, disabled claims, failed saves, backup round-trip,
and legacy imports. The native suite must be run on an Apple SDK environment.

Completed checks on the final source:

- `git diff --check`: passed.
- Tree-sitter Swift syntax parsing: all 13 changed/new Swift files passed.
- Info.plist and project.yml parsing: passed; matching foreground location
  purpose strings and no background-location capability verified.
- Independent source review: midnight cache and test backup-isolation issues
  were found and corrected. Existing core scoring files remain unchanged.

This implementation was prepared on Linux with no Swift or Xcode executable.
Static checks are not a successful native build or simulator test. Before
merge or distribution, run:

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID xcodegen generate
xcodebuild -project Roastie.xcodeproj -scheme Roastie \
  -configuration Debug -destination 'generic/platform=iOS' build-for-testing
# Select an installed iOS 26 simulator UDID for executable unit/UI tests:
xcodebuild -project Roastie.xcodeproj -scheme Roastie \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' test
```

Manual device/simulator checks still required:

1. Fresh install and migrated settings: off, no location prompt/network.
2. Enable then close/reopen Settings: no prompt until Check Weather.
3. Allow approximate location, deny/restrict location, and change permission
   while a request is pending. Core logging always remains usable.
4. Disable/re-enable during location lookup and weather request: no late
   result can repopulate disabled UI. Offline and timeout states allow retry.
5. Repeat completion taps, relaunch, toggle off/on, and cross local midnight:
   only one badge per day; old weather requires refreshing for the new day.
6. Verify light/dark themes, large Dynamic Type, VoiceOver, and narrow iPhone
   layout. Check weather status/error, completion, and long suggestion copy.
7. Compare core score/verdict/goals before and after completion and inspect
   backup JSON for no location/weather/suggestion data.

The Open-Meteo link provides attribution. Confirm the provider's current
licensing/service terms and suitability for the app's distribution model
before release, especially if commercial use is planned. No account, API key,
paid plan, remote branch, PR, merge, or deployment was created by this work.

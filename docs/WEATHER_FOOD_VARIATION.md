# Weather food variation

Based on upstream `main` at `d722cbab7a5e63fd0f7f2abb8fadfc379c7dd90e`
(PR #12), which already includes the regional collapsible UI from PR #11
and text-based persistence of followed picks. The old cloud checkout and
its uncommitted Siri work were left untouched. No repository AGENTS.md or
.agents/skills files were present in this checkout or its workspace parents.

## Cause and fix

`SurroundingsSuggestion.foodPointers` previously selected one fixed `Foods`
record per broad region, then returned three fixed templates for the weather
group. It never used a date or previous suggestions. Remaining in the same
region and weather group therefore produced identical foods indefinitely.
Warm and humid deliberately share a cooling-food presentation. This was
local deterministic content, not a stuck AI response or a failed weather API.

Each region now has four sets of actual food examples. The local Gregorian
civil date selects one set on a four-day cycle. Every slot changes across
those four days; the list is not merely reordered. The cycle then repeats.
The weather group continues to choose suitable types (cool snacks for heat,
warm meals for cold, easy home meals for rain). No diet/allergy is inferred.

The card explicitly passes its TimelineView date into food selection.
Repeated renders, re-expansion, relaunches, and new fetch timestamps do not
reshuffle foods within the same local day, region, and weather group. A
material weather-group or region change may change suggestions sooner.
No new shuffle control, persistence, identifiers, or network request is added.
The local civil date is normalized to a UTC date before counting days to
handle fractional time zones and 23/25-hour daylight saving days correctly.

Followed ideas remain stored by their text and displayed under Followed today
when they leave the current list. The existing daily cap is unchanged: water
+1, up to three distinct followed food ideas +1 each, maximum +4 separately
from core score. Off-by-default opt-in, hydration goals, calories, macros,
core score, and existing storage/backup schemas are unchanged.

## Exactly how weather is accessed

The implementation is in `Roastie/SurroundingsWeatherService.swift`:

1. `AppSettings.surroundingsAwarenessEnabled` defaults to false. Enabling it
   only sets explanatory status text. It does not request location or weather.
   Today calls `refresh()` only from the Check Weather button.
2. An enabled refresh uses a usable in-memory snapshot first. Otherwise it
   creates a foreground CLLocationManager, requests When In Use authorization
   if needed, sets kilometer desired accuracy, and calls `requestLocation()`.
   There is no continuous/background location subscription. Denied/restricted
   permission produces an error. Location lookup has a 45-second timeout.
3. It accepts a valid coordinate with nonnegative horizontal accuracy and a
   timestamp within five minutes of now. Desired accuracy is a request to iOS,
   not a guarantee of the precision returned. Both coordinates are rounded to
   one decimal place (0.1 degree) before any network request. The location
   manager is stopped/released before the weather fetch.
4. The app sends a direct HTTPS GET to
   `https://api.open-meteo.com/v1/forecast` with exactly these query fields:

   ```text
   latitude=<rounded latitude>
   longitude=<rounded longitude>
   current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code
   temperature_unit=celsius
   timeformat=unixtime
   timezone=GMT
   ```

   It uses Open-Meteo, not WeatherKit or an AI/weather proxy. There is no API
   key in this request. The provider receives those rounded coordinates and
   normal connection information, including the source IP. No health logs,
   food entries, notes, or app-specific user identifier is added.
5. URLSession uses an ephemeral configuration, no URL cache, and
   reloadIgnoringLocalCacheData; timeouts are 15 seconds per request and
   20 seconds per resource. Only HTTP 200 and valid finite measurements,
   humidity, weather code, and provider timestamp are accepted. Provider data
   may be up to two hours old or ten minutes ahead of the device clock.
6. The snapshot timestamp (`observedAt`, also the UI's Updated time) is the
   successful fetch time, not the provider's source time. The snapshot is
   usable for less than 30 minutes and only within that same local calendar
   day. A scheduled task clears it after 30 minutes; presentation also checks
   freshness on its minute timeline. Check Weather inside the valid cache
   window reuses it without another location or network request. Expiry alone
   does not fetch again: a new button tap is required.
7. Rounded coordinates select one of nine coarse geographic boxes or a
   general fallback on-device. There is no reverse geocoding or diet inference.
   The region lives only in the in-memory weather snapshot. Coordinates,
   region, and weather are not written to logs, backups, model prompts, or
   notifications. Only followed idea text and water bonus time persist.
8. Disabling cancels pending location/network work, clears the snapshot and
   expiry task, and fences late callbacks with a generation ID. It cannot
   retract an already-sent request or revoke the OS location permission.

Weather classification is unchanged, in precedence order: warm when feels
like >=28 C or actual >=30 C; otherwise humid when humidity >=75% and actual
>=24 C; otherwise cool when actual <=10 C; otherwise wet for the listed
precipitation codes; otherwise mild. Small changes within a group do not
shuffle foods. Weather classifications are comfort hints, not alerts.

The prior privacy policy incorrectly said only pick positions were saved.
It now describes the text-based storage already implemented by PR #12 and
explains that daily rotation is on-device. The weather request is unchanged.

## Verification

On Linux, using the official Swift 6.0.3 release toolchain:

```sh
scripts/test-surroundings.sh
TZ=Asia/Kolkata scripts/test-surroundings.sh
```

Both runs passed all 22 XCTest cases (9 new rotation tests plus 13 existing
weather/region/hydration tests), compiling the actual Shared/Surroundings.swift
and the same test sources used by the iOS target. The portable runner creates
and removes a temporary Swift package; it does not edit the app project.
The settings round-trip test was moved unchanged to SurroundingsSettingsTests
so the pure Foundation suite can run without SwiftData.

The new tests cover all 10 regions x 5 weather groups x 4 days, three distinct
bounded ideas per set, actual slot variation, same-day/recreated-object
stability, fresh weather fetches, local midnight, DST spring/fall, year-end,
leap day, weather suitability, and alternate display-calendar identifiers.

Negative control: running the four-day variation test against upstream's
original production source, with only the new date/calendar parameters added
for signature compatibility, fails with 200 assertions (50 combinations x
one list assertion and three slot assertions). The fixed production source
passes. This confirms the tests detect the reported fixed-list behavior.

`git diff --check`, shell syntax validation, and Swift frontend parsing of
the changed UI/native persistence tests also passed. The native persistence
regression now includes a rotated list while checking that the original pick
stays stored and the food cap still applies.

The SwiftUI/CoreLocation/SwiftData integration tests, including settings,
permission/cancellation, pick persistence, and core-score invariance, were
not executed here. Linux has no Apple SDK/Xcode, and the Mac is offline.
Before merge, use the existing XcodeGen project and an iOS 26 simulator:

```sh
xcodegen generate
xcodebuild -project Roastie.xcodeproj -scheme Roastie \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' test
```

Also inspect the collapsed food list and Followed today on an iPhone/simulator.
No merge, release, or deployment is part of this fix.

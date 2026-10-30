# Partial food scoring (issue #1)

Scoring version 3 averages only entries with a usable assessed verdict/score.
An unresolved entry is retained verbatim and excluded, not assigned zero. A real
unhealthy score of zero still counts. Empty and all-unresolved logs have no score.
Legacy healthy/unhealthy entries retain the existing 90/30 defaults and clamping.

Coverage is **entry count**, not calorie coverage or model confidence. It is
recomputed from persisted `FoodEntry` values, including restored backups and days
whose version-2 cache was nil. No new persisted schema is needed. Today and History
show the partial estimate and assessed/total count. The overall score includes that
estimate with the existing weights but remains provisional. Comparable food trends
include only fully assessed days and disclose partial-day exclusions and unresolved
entries. Partial days are not counted as complete days.

Unassessed entries can be reviewed/corrected or deleted in History. Recovery
feedback is visible even with food roasting disabled. This change does not introduce
a background retry loop, item-level meal parsing, or claim that unfamiliar food is
always detected: the current model schema still returns a mandatory healthy boolean.
It fixes entries already represented as `.unanalyzed` (for example model failures).

Late model responses cannot overwrite a corrected/edited entry or resurrect a
deleted entry. Daily narrative results are discarded if the entry snapshot changed
while generation was suspended. Partial food days skip a whole-day model narrative.

## Validation required before merge

The implementation was prepared on Linux without Swift/Xcode. `git diff --check`
and source-contract checks ran; **Swift compilation, XCTest, simulator, real model,
and physical-device validation have not run**. No release or merge is included.

On a Mac with the repository's Xcode/iOS 26 setup, generate the project per README,
then run the focused suites (and the full test suite) on an available iOS simulator:

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID xcodegen generate
xcodebuild -project Roastie.xcodeproj -scheme Roastie \
  -destination 'platform=iOS Simulator,name=YOUR_SIMULATOR' \
  -only-testing:RoastieTests/FoodScoreCalculatorTests \
  -only-testing:RoastieTests/DailySummaryCalculatorTests \
  -only-testing:RoastieTests/LongitudinalInsightsCalculatorTests \
  -only-testing:RoastieTests/BackupManagerTests test
```

Also check on-device: known + failed analysis, roasting off recovery alert,
correction/deletion while analysis is pending, relaunch, backup restore, and Today /
History / daily report / Insights consistency. The added pure update-guard tests
cover concurrent entry snapshots; they are not a substitute for coordinator/UI tests.

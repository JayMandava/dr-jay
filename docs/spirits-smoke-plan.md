# Spirits and Smoke Easter eggs

User-authorized scope: implement on `feature/spirits-smoke-easter-eggs`; do not merge, push, or release.

## Frozen implementation plan

- Match only trimmed, case-insensitive `Spirits` and `Smoke` submissions in Brain Dump before adding conversation messages or invoking a model.
- Open a hidden sheet in the existing visual language. Support both exposure types, day selection, notes, correction, and deletion. Explain that explicitly saved entries persist even though ordinary Brain Dump conversations disappear.
- Add optional Codable exposure entries to existing daily logs and backwards-compatible backup support. Use coordinator save/rollback conventions.
- Feed entries into both Today and coordinator summary paths. Subtract deterministic, bounded, monotonic penalties after existing weighted scoring; classify the resulting score.
- Alcohol: UK units (10 ml pure alcohol). Fractional quantities from 0.5 units are accepted (volume in ml × ABV% ÷ 1,000). Product policy: 8 points/unit plus 12 additional points/unit above 2 units/day. Smoking: individual cigarettes, 20 points each from the first. Combined deduction capped at 100. Two units is an app escalation threshold, not a safe-drinking guarantee; this is a motivational score, not a clinical risk measure.
- Use fixed high-intensity, behavior-focused exposure commentary without changing unrelated roast preferences. Ensure generated daily reports cannot omit the recorded impact.
- Cover command near misses, zero/boundary/excess/large counts, profiles, edits/deletes, persistence, backups, and reports. Build app/widgets, run tests, and exercise simulator UI when available.

## Evidence and process limits

Planner inspected the existing SwiftUI/SwiftData architecture. `DailyLog` remains the source of truth; Presence provides the mutation convention. Existing sleep/water streak semantics remain outside this feature.

The environment does not expose `record_cycle`, `grill`, or `approve_plan`; lifecycle database records cannot be written through the prescribed tools. This file records the implementation scope without claiming those unavailable steps occurred. The user's explicit implementation request authorizes this feature branch work.

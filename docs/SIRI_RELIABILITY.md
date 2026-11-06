# Siri water/sleep reliability

The existing Siri/App Shortcuts and duration choices remain supported. Siri is the
voice interface; saving a bottle or sleep duration does not wait for on-device LLM
commentary. This is not a general conversational AI or food-logging integration.

## Contract

- One invocation performs one synchronous, main-actor mutation/save. A success
  receipt is constructed from the saved log, not a potentially stale snapshot.
- Save failures restore changed fields and throw a localized failure instead of
  saying "Logged". Setup must be complete. Invalid/non-finite durations are rejected.
- Deterministic check-in text is saved in the same transaction. The lightweight
  shared snapshot is updated immediately. HealthKit reads, notification scheduling,
  Live Activity refresh and backup are best-effort ancillary work; suspension of
  that task does not undo the saved entry or make the success receipt depend on AI.
- Status reads fetch today's persisted row without creating one. Old-day data is
  rejected, and read errors are distinguished from no data. Ancillary updates check
  the day again after awaits so a crossed-midnight response cannot schedule the old
  day's summary.
- Yes/no confirmation preserves HealthKit data and truthfully reports no change.
  Without Health data, the existing goal self-report approximation remains, but its
  receipt explicitly calls it an estimate. Exact-duration logging remains additive
  and makes the manual total authoritative, as before.
- No automatic mutation retries or guessed time-window deduplication. AppIntent
  does not provide this implementation a stable invocation identifier. Deliberate
  repeated bottle/sleep commands must still count; separate user retries cannot be
  safely distinguished. The receipt includes the resulting total for verification.

## Verification status

`git diff --check` and independent source review passed. Sixteen focused XCTest
cases were added, including save-failure rollback, correct totals, onboarding,
invalid durations, current-day/old-day/no-record status, HealthKit conflict,
repeated intentional invocations, supported duration mappings, and an in-memory
SwiftData write/read through a fresh context.

**Swift compilation, all XCTest execution, Siri speech/Shortcuts runtime,
simulator, locked-device and physical-device testing remain unrun.** The Linux
executor has no Swift/Xcode or iOS SDK. The fresh-context test is persistence
integration, not proof of an actual Siri intent invocation or cold process launch.

Before merge, generate the project per README and run the full native suite,
including `RoastieTests/SiriLoggingTests`. On an iPhone test the same actions via
Shortcuts directly and via spoken Siri, warm/cold/locked, Apple Intelligence
available/unavailable, Health permission granted/denied, immediately after midnight,
and with intentional repeated commands. Verify each acknowledged entry appears once
with the spoken total. Simulate persistence/read failure in an isolated test store.

Existing `PersistenceController` still terminates on container-open failure;
locked/pre-first-unlock store availability and background task suspension need native
verification. This change neither relaxes device authentication nor modifies file
protection or permissions. No merge, release or signing is included.

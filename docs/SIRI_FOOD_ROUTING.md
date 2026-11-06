# Siri food routing fix

Based on merged main `f3fe33c7e610a6d7b7190b311070b14450d95f2a` (PRs #2 and #3).
The user reported that saying “log food to Dr Jay” logged water. Source inspection
confirmed there was no food intent or food shortcut, and water could mutate without
parameters or confirmation. This is consistent with Siri selecting another route;
the exact speech-routing behaviour has not been reproduced in this environment.

## Changes

- A separate `LogFoodIntent` registers “Log food to/in Dr Jay” and meal variants.
  Siri asks “What did you eat?” through a required free-text parameter. Empty text
  is rejected without saving. Food goes only through the food logging pipeline.
- Food opens Dr Jay for the existing foreground/on-device assessment flow. If
  assessment is unavailable, the entry remains saved and the receipt says it needs
  review. The entry is saved before analysis is awaited; cancelling Siri during
  assessment can therefore leave a saved food entry. Check the app before repeating
  that command; no automatic retries are performed. This is not an assertion of nutrition accuracy or guaranteed recognition.
- The initial food save now rolls back on failure and cannot report a saved entry
  after that failure. No automatic persistence retries are introduced.
- Water now explicitly asks whether to log one bottle of WATER before touching the
  coordinator/store. Cancelling prevents the mutation. This adds one confirmation
  to normal Siri water logging; the existing water/sleep phrases remain intact.
- The app calls the supported AppShortcuts parameter update API at launch. This is
  not a guarantee of immediately clearing Siri's cached/disambiguation behaviour.

The app does not receive Siri's original utterance inside a selected parameterless
water intent, so it cannot reliably filter “food” there. Explicit food registration
plus water confirmation addresses that gap without inventing an utterance parser.

## Validation

`git diff --check` and eight source-contract checks passed. Six synthetic XCTest
cases cover food isolation, blank input, failed-save rollback, partial scoring,
water-confirmation cancellation and one confirmed water save. Existing water/sleep
tests remain unchanged. No real health records were created or modified.

**Swift/XCTest, App Intents metadata extraction and actual Siri speech tests are
unrun here:** no Swift/Xcode/iOS SDK or Dr Jay coding environment is available.
Before merge, run native build/tests, open the updated app once, inspect the Log Food
shortcut, and test direct Shortcuts plus spoken “log food to Dr Jay”. Confirm that
Siri asks for food and water stays unchanged. Also test “log water to Dr Jay”, cancel
its water prompt, accept it once, and recheck the working sleep commands. Use a
throwaway test installation/store, not the user's live health history.

Apple references:
- https://developer.apple.com/documentation/appintents/appintent/requestconfirmation(conditions:actionname:dialog:)
- https://developer.apple.com/documentation/appintents/appshortcutsprovider/updateappshortcutparameters()
- https://developer.apple.com/videos/play/wwdc2023/10102/

No merge, release, signing, authentication or file-protection changes are included.

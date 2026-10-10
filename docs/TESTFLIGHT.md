# Dr Jay TestFlight preparation

Dr Jay targets iOS 26 or later. Prepare the binary and privacy materials before enrolling; paid membership, distribution signing, App Store Connect setup, and Apple's beta review are separate release gates.

## Repository configuration

The app and widgets share marketing version and build number in `project.yml`. Increment `CURRENT_PROJECT_VERSION` before each upload and regenerate with `xcodegen generate`. The widget is embedded in the app but is not independently installed by Archive. The Archive action uses Release.

Privacy manifests cover App Group/private defaults and the model-download free-space check. The pinned CLiteRTLM dynamic framework uses file metadata for model-cache identifiers and elapsed-time APIs. Its separate manifest is copied into the embedded framework and the framework is re-signed before final app signing. Do not move those declarations only into the app manifest. Review the SDK declarations whenever upgrading LiteRT-LM.

Dr Jay marks its app-owned SQLite database, WAL/SHM sidecars, and automatic JSON backup for backup exclusion. It must not set metadata on the protected App Group root: physical iOS rejects that operation. Database metadata errors are logged separately and do not prevent store opening. Shared preferences and widget snapshots still need a separate backup audit before distribution. Explicit exports remain user-controlled. Development-signing expiry UI and backup reminders depend on an actual development profile; missing or distribution profiles do not produce a guessed expiry.

Settings → About contains the bundled privacy policy and license notices. The public policy is [PRIVACY.md](../PRIVACY.md). Confirm the direct privacy-contact email before external beta distribution. The optional Gemma 4 E2B artifact is Apache 2.0; older Gemma terms are not its license. The upstream LiteRT binary's dependency notices remain bundled and readable.

## Build and test commands

Run the hosted unit suite on an available simulator or physical phone:

```sh
xcodebuild -project Roastie.xcodeproj -scheme Roastie \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Before paid signing is available, create an unsigned structural archive:

```sh
xcodebuild -project Roastie.xcodeproj -scheme Roastie \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/DrJay.xcarchive archive CODE_SIGNING_ALLOWED=NO
bash scripts/check-release-archive.sh /tmp/DrJay.xcarchive
```

An unsigned archive cannot be uploaded or installed. After enrollment, create a fresh signed archive with the paid team, use Xcode Organizer → Validate App, and review the generated privacy report before uploading. Use a released Xcode/SDK version accepted by App Store Connect; the local Xcode beta is not evidence of upload eligibility. Verify the actual supported minimum OS and device list in the processed build.

## Physical release checks

Complete these on the signed Release build without erasing real entries; use a dedicated test installation for clean-state or destructive checks.

- Fresh onboarding and Health/notification permissions, including denial and later enabling access.
- Apple Intelligence unavailable, disabled, unsupported language, or preparing its model; the UI should explain limitations and preserve logging.
- Sleep/manual reconciliation, water, food correction memory, optional exercise, scores, and insights.
- JSON export/import, legacy backups, and an update over an existing installation without data loss.
- Cold and warm app launches from the 10 p.m. notification.
- Home/Lock Screen quick-log buttons, successful-save feedback, repeated taps, Live Activities, and day rollover.
- Gemma download cancellation, resumed download, low storage, failed verification, deletion, and on-device generation. Keep Gemma optional and avoid requiring its large download for reviewers to use core features.
- Brain Dump dismissal/background privacy, unrelated questions, prompt extraction, vulnerable beliefs, and immediate-risk routing. Confirm conversations are absent from exports and diagnostics.
- Settings appearance changes, offline policy/license reading, large text, and light/dark legibility.

Simulator tests do not verify Health background delivery, haptic hardware, real model performance, or scheduled iOS execution. Mark those checks separately rather than treating compilation as a pass.

## App Store Connect after enrollment

Register or confirm `dev.jeyanth.roastie`, `dev.jeyanth.roastie.widgets`, and `group.dev.jeyanth.roastie` under the intended individual team. Enable HealthKit and App Groups, create the app record, and confirm distribution signing for both app and extension. Back up before changing signing teams: App Group access and sideload-to-TestFlight continuity must be checked on the actual signed build.

Provide a beta description, feedback email, privacy-policy URL, review contact, review notes, and What to Test. No app login is needed. Explain Health's read-only access, optional permissions, on-device model requirements, Gemma's optional download, ephemeral Brain Dump, and deterministic scores with model-written commentary. Complete export-compliance and privacy answers based on the actual packaged app and network behavior; a manifest is not a substitute for App Store Connect's questionnaires.

Start with internal testing and confirm installation through TestFlight. Submit the first external build for beta review, then invite a small group. Open the public link after checking crash reports and core flows. Public App Store release is a separate step.

## Required release gates

Preparation verified on October 10, 2026: 58 hosted unit tests passed on the
iOS 27 simulator; an unsigned Release archive passed the structure checks;
the development-signed app passed deep, strict signature verification.
Physical Release smoke testing and App Store Connect validation are still
required. These results do not establish iOS 26 device behavior or upload
eligibility for the local beta SDK.

- Direct private contact email and public policy confirmed.
- Shared preferences and widget-snapshot backup handling audited for HealthKit data before distribution.
- Hosted unit suite passed on the final sources.
- Signed Release smoke checks completed on a physical phone.
- Paid-team archive validates, including nested framework signing and privacy report.
- App Store Connect processing and external beta review succeed.

## References

[Apple privacy manifests](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy), [TestFlight](https://developer.apple.com/testflight/), [Gemma 4 license](https://ai.google.dev/gemma/apache_2), [pinned LiteRT file-cache metadata code](https://github.com/google-ai-edge/LiteRT-LM/blob/v0.17.1/runtime/util/file_util.cc).

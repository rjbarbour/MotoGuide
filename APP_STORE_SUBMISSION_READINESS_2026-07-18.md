# RideHorizon App Store Submission Readiness

Date: 2026-07-18

## Outcome

RideHorizon is not ready for App Store submission yet. A clean unsigned Release build succeeds, but several technical, privacy, production, and App Store Connect items remain.

The highest-risk gotchas are:

1. The 1024 px App Store icon contains an alpha channel.
2. The target has macOS sandbox entitlements instead of a clean iOS entitlement set.
3. Seven background modes are declared, while the code appears to use only background audio and location.
4. A privacy manifest is now included, but it must be checked in the final signed archive and reconciled with App Store Connect.
5. Explicit, revocable AI-sharing consent is implemented, but the final physical-device build must verify the decline and withdrawal paths.
6. The app has an in-app privacy notice, but a published HTTPS privacy-policy URL is still missing.
7. The app still targets iPad, but current validation and release preparation are iPhone-focused.
8. The production app still selects the legacy proxy host, while the planned App Attest access path is incomplete.
9. A signed archive has not yet been validated in Xcode Organizer.

## Verified Project State

| Check | Current state | Submission impact |
|---|---|---|
| Release build | Clean unsigned Release build succeeded on 2026-07-18 | Good, but this does not prove signing or upload validity |
| Xcode | Xcode 26.3, iOS SDK 26.2 | Meets Apple's requirement for Xcode 26 and an iOS 26 SDK |
| Bundle ID | `ai.digitalmercenaries.ridehorizon` | Confirm it exactly matches the App Store Connect record |
| Version | `0.12.3` | Valid if intentional; choose the public version before upload |
| Build number | `20260708.1650` | Must be unique for every uploaded build |
| Device family | iPhone and iPad | Requires iPad QA, correct layout, and iPad store assets; otherwise change to iPhone-only before the first release |
| App Store icon | 1024 x 1024, alpha channel present | Flatten the icon to remove transparency before archiving |
| Privacy manifest | Included in the iOS target; unsigned Release bundle verification passed on 2026-07-18 | Recheck the signed archive privacy report and reconcile it with App Store Connect |
| Entitlements | macOS App Sandbox and user-selected-file entitlements | Remove these from the iOS target; add only entitlements actually used |
| Background modes | audio, Bluetooth central, Bluetooth peripheral, external accessory, fetch, location, processing | Keep only modes supported by real functionality and review notes; current code appears to justify audio and location only |
| Export compliance key | Missing | Complete Apple's export-compliance questions and set the plist answer only after confirming the correct classification |
| App Attest | Planned but incomplete | Finish it before relying on it to protect the production proxy |

## P0 — Fix Before Uploading a Release Candidate

### 1. Correct the app icon

Remove the alpha channel from `RideHorizon/Assets.xcassets/AppIcon.appiconset/1024.png`, then inspect the rendered icon on light and dark backgrounds. An apparently opaque image can still contain an alpha channel and fail asset validation.

### 2. Clean the iOS entitlements

Remove these macOS-only entitlements from the iOS application target:

- `com.apple.security.app-sandbox`
- `com.apple.security.files.user-selected.read-only`

If App Attest will be active in the submitted build, add the correct App Attest entitlement and confirm it is present in the signed archive. Do not add capabilities merely because they may be useful later.

### 3. Reduce background modes

The current plist declares seven modes. Code inspection found a clear use for background location and audio, but not for Core Bluetooth central/peripheral, external accessories, background fetch, or BG processing.

Remove unused declarations. Apple may ask why each background mode is necessary, and `processing` can create additional configuration and review expectations. The review notes should explain that location identifies place changes and audio speaks short optional announcements while the screen is locked or another navigation app is visible.

### 4. Validate the privacy manifest in the signed archive

`PrivacyInfo.xcprivacy` is now in the application target. Before upload, confirm that the signed archive:

- declare that the app does not track users;
- list any accessed required-reason API categories;
- use an approved reason matching the actual same-app `UserDefaults` use;
- be re-audited whenever an SDK is added.

The repository currently has no third-party iOS SDK dependency, which simplifies this check.

### 5. Validate consent before third-party AI processing

The app now requires an explicit Allow or Decline choice before tracking begins and gates OpenAI and ElevenLabs calls on that saved decision. On the final physical-device build, verify that the screen identifies:

- what is sent;
- why it is sent;
- which third parties receive it;
- whether it is retained;
- how the user can decline or withdraw consent.

Verify that withdrawal immediately cancels queued AI work and falls back to Names Only/Apple Voice. Confirm with proxy/provider observations that no third-party request occurs after decline or withdrawal.

### 6. Publish and link the privacy policy

Publish an HTTPS privacy policy before submission and add its URL in App Store Connect. The app now has a notice in the consent flow and Settings; add the published policy URL to those locations once it exists.

The policy needs to match the actual app and proxy behaviour, including location precision, derived place data, device/session identifiers, AI providers, retention, deletion, security, user choices, and a contact address. Resolve OpenAI and ElevenLabs retention settings before writing final claims.

### 7. Validate sensitive production logging controls

The iOS privacy batch compile-gates value-bearing diagnostics and uses value-free Release messages. Recheck the final archive and production proxy logs to confirm they do not expose precise coordinates, resolved addresses, complete prompts, generated phrases, tokens, device identifiers, or provider responses. Use a deliberate retention policy for server logs.

### 8. Finish the production service path

The application currently selects the legacy `motoguide-fact-proxy.fly.dev` route. Before submission:

- select the intended RideHorizon production host;
- confirm TLS, health checks, timeouts, rate limits, and failure behaviour;
- ensure App Review can exercise the core flow without a manual secret or invite code;
- finish App Attest enforcement, database migrations, replay prevention, and client integration if App Attest is part of the launch security boundary;
- keep provider secrets only in the approved secrets system, never in the app bundle or logs.

App Attest is a production-security blocker if the service is otherwise publicly usable at someone else's expense. It is not a substitute for privacy consent.

### 9. Create and validate a signed archive

After the fixes, archive the Release scheme using the distribution identity. In Xcode Organizer, run **Validate App** before upload. This catches provisioning, entitlement, icon, architecture, privacy-manifest, and bundle metadata errors that an unsigned build cannot catch.

## P1 — Complete Before Sending to App Review

### App Store Connect record

- Confirm the app name, subtitle, primary category, bundle ID, SKU, and primary language.
- Prepare the description and keywords without calling the app navigation, safety, or emergency software.
- Use a support URL that opens a working page with real contact information.
- Add the privacy-policy URL.
- Add copyright and accurate content-rights answers.
- Set price and country/region availability.
- Complete the current age-rating questionnaire. Apple requires the updated questions; consider the possible range of AI-generated history and culture content.
- Declare Digital Services Act trader status. A company offering the app as part of its business is likely a trader; verify the legal details and complete Apple's email, telephone, and address verification.
- Complete export-compliance questions for the app's HTTPS and platform cryptography. Get legal advice if the exemption classification is unclear.
- Confirm that all account-level developer agreements are active. Banking and tax details may still be needed for paid apps or in-app purchases; they normally should not block a genuinely free app with no paid content.

DSA verification is an exception to that last point: Apple may require payment-account details from an EU trader even when the app itself is free.

### iPhone versus iPad decision

Choose one path before release:

1. Keep universal support: test every important flow on supported iPads, fix layouts and rotation, and supply the required 13-inch iPad screenshot set.
2. Make the first release iPhone-only: change the target device family, rebuild, and validate the final binary.

Do not leave iPad enabled by accident. App Review can test any declared device family.

### Store assets and metadata

- Capture screenshots from the final release candidate, not a debug build.
- Ensure every screenshot represents real behaviour and contains no placeholder or unsupported claim.
- Remove transparency from screenshot files as well as the app icon.
- Check the icon, app name, screenshots, onboarding terminology, privacy policy, and review notes use the same product name.
- Provide attribution for licensed onboarding imagery in an accessible acknowledgements screen, including source and licence links where the licence requires them.
- If the app displays third-party or AI-generated material, confirm the content-rights answer is accurate and add a reporting/support path for problematic output.

### Review information

- Use a monitored contact email and telephone number.
- Leave sign-in credentials blank only because the app genuinely has no sign-in requirement.
- Give exact test steps: onboarding, location permission, announcement selection, optional Bluetooth setup, and how to hear an announcement.
- Provide a reviewer test route or fully featured demonstration that exercises place changes without requiring the reviewer to undertake a motorcycle journey.
- Explain background location and audio in plain language.
- State that the app is an audio place-awareness companion, not navigation, safety, or emergency software.
- Disclose any feature that depends on the production proxy and describe graceful offline behaviour.

## P1 — Release-Candidate QA

Run this matrix on physical devices using the exact archived configuration:

- fresh install and upgrade from the latest TestFlight build;
- location allowed once, while using, always, denied, and later changed in Settings;
- screen locked for an extended journey;
- Apple Maps or another navigation app in the foreground;
- Bluetooth helmet/headset connected, disconnected, and switched mid-session;
- cellular handoff, weak connection, airplane mode, proxy timeout, and provider outage;
- an IPv6-only network;
- repeated border/place changes to catch duplicate or excessive announcements;
- Dynamic Type, VoiceOver, dark mode, and reduced motion where relevant;
- every supported iPhone size and every supported iPad class if iPad remains enabled;
- no debug panels, placeholder text, internal hosts, test credentials, or raw diagnostic data in Release.

The permission prompts, onboarding copy, privacy policy, App Privacy answers, and actual network requests must agree.

Apple's Accessibility Nutrition Labels are voluntary as of 2026-07-18. Do not claim VoiceOver, Larger Text, Voice Control, or another accessibility feature until all common tasks work with it, but do not treat the absence of a label as a current submission blocker.

## App Privacy Answers to Reconcile

The detailed privacy audit recommends answering **Yes** to data collection. The conservative working categories are:

- Coarse Location;
- Other User Content;
- Device ID;
- Product Interaction;
- Other Diagnostic Data;
- Other Data.

Declare **No** for tracking only if the final app, proxy, providers, and privacy manifests do not link data across other companies' apps or websites for advertising, measurement, or data-broker purposes. Recheck the answers against a captured Release network trace and the final provider contracts immediately before submission.

See `PRIVACY_AUDIT_2026-07-18.md` for the evidence and remediation detail.

## Recommended Order

1. Decide iPhone-only versus universal iPhone/iPad support.
2. Fix the icon, entitlements, background modes, and privacy manifest.
3. Finish the consent flow, in-app privacy link, policy, logging, and deletion/retention behaviour.
4. Finish and harden the production proxy path, including App Attest if it is required for launch.
5. Run physical-device release-candidate QA.
6. Complete metadata, URLs, screenshots, age rating, DSA, content rights, export compliance, price, and availability in App Store Connect.
7. Archive, validate, and upload the signed build.
8. Select that processed build on the App Store version page, answer the remaining compliance prompts, and submit it for review.
9. Use manual release or a deliberate phased release so approval does not publish an unmonitored build unexpectedly.

## Go/No-Go Gate

Submit only when every item below is true:

- [ ] App Store icon has no alpha channel.
- [ ] Signed archive validates successfully.
- [ ] Entitlements and background modes match implemented features.
- [ ] Privacy manifest is included and valid.
- [ ] Explicit third-party AI consent works before the first disclosure.
- [ ] Privacy policy is live, accurate, and linked in the app and App Store Connect.
- [ ] App Privacy answers match measured Release behaviour.
- [ ] Provider retention and user deletion processes are documented and working.
- [ ] Release logs do not expose personal data or secrets.
- [ ] Production proxy is stable and reviewer-accessible.
- [ ] App Attest is complete if it is part of the production access boundary.
- [ ] iPhone/iPad support decision is reflected in the binary, QA, and screenshots.
- [ ] Metadata, screenshots, age rating, DSA, content rights, export compliance, price, and availability are complete.
- [ ] Core journeys pass on physical devices under locked-screen, Bluetooth, denied-permission, navigation-coexistence, and network-failure conditions.
- [ ] Review notes accurately describe the app and provide reproducible test steps.

## Apple References

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Upcoming submission requirements: https://developer.apple.com/news/upcoming-requirements/
- Submit an app: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app
- Required and editable App Store properties: https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/
- App information fields: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- Privacy manifests and required-reason APIs: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Digital Services Act trader requirements: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements

## Validation Performed

Command:

`xcodebuild build -project RideHorizon.xcodeproj -scheme RideHorizon -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/ridehorizon-submission-audit-derived CODE_SIGNING_ALLOWED=NO`

Expected and observed result: `** BUILD SUCCEEDED **`.

This result proves that the current source compiles as an unsigned generic iOS Release build. It does not prove that a signed archive will validate or upload.

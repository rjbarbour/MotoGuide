# RideHorizon Privacy Audit

Date: 2026-07-18

Status: Code remediation implemented; external verification remains before external TestFlight review

## Implementation Batch — 2026-07-18

User request: address the privacy issues identified by this audit.

Rationale: RideHorizon must prevent third-party AI disclosure until the rider makes an informed choice, minimise what leaves the device, avoid sensitive diagnostic output, and make its local privacy controls and manifest match the shipped behaviour.

Acceptance criteria for this code batch:

1. A new install must make an explicit Allow or Decline choice before ride tracking begins. Existing installs with no recorded choice must also be stopped at that choice.
2. Declining or withdrawing consent must prevent OpenAI fact requests and ElevenLabs speech requests. The app must fall back to place-name/natural announcements and Apple Voice.
3. Settings must show the current choice, identify OpenAI and ElevenLabs, allow withdrawal, and provide an accessible in-app privacy notice.
4. A confirmed local-data clearing action must clear cached facts, rider context, consent, session ride history, app preferences, and Keychain-held installation/proxy credentials, then return the app to setup.
5. Fact requests must omit street data and send only the hierarchy at or above the announced boundary.
6. The Release/TestFlight path must not print coordinates, resolved addresses, announcement text, rider text, cache keys, tokens, device identifiers, or provider response content.
7. The app bundle must include a valid `PrivacyInfo.xcprivacy` declaring no tracking and the approved same-app `UserDefaults` reason.
8. The proxy must request ElevenLabs zero-retention processing, expire inactive rate-limit identities, and automatically delete expired/consumed invite and credential records under documented retention windows.
9. Unit tests must cover consent persistence, denied-consent network gating, hierarchy minimisation, cache clearing, zero-retention request construction, rate-limit expiry, and database cleanup.

External actions that code cannot complete:

- publish a legally reviewed privacy policy at a stable HTTPS URL and configure that URL in App Store Connect;
- confirm that the ElevenLabs account is authorised for Zero Retention Mode;
- confirm OpenAI organisation retention controls and provider contracts;
- deploy the proxy migration/cleanup changes and verify the production log/edge-retention configuration;
- implement and operate a verified server-side deletion-request endpoint before promising remote deletion in the public policy.

This is an implementation and App Store submission audit, not legal advice. It describes the current checkout, including uncommitted work visible on 2026-07-18. It does not assume that planned App Attest code is complete or deployed.

## Outcome

RideHorizon cannot accurately answer “We do not collect data” in App Store Connect. The app and its service providers can retain location-derived place information, rider-entered content, an installation identifier, service-usage timestamps, and technical request data.

The current design does not use advertising, data brokers, cross-company advertising measurement, or tracking as Apple defines it. App Tracking Transparency is not required for the audited behavior.

The 2026-07-18 implementation batch resolved the two original code blockers: explicit, revocable AI-sharing consent now gates OpenAI and ElevenLabs access, and the iOS bundle includes `PrivacyInfo.xcprivacy` with tracking disabled and the approved same-app `UserDefaults` reason. The app also provides an in-app privacy notice, local-data clearing, request minimisation, Release-safe diagnostics, bounded cache retention, and proxy cleanup controls.

External TestFlight still requires a published privacy-policy URL, verification of provider/account retention settings, deployment and production verification of the proxy changes, and physical-device ride/audio/background validation. The local clear action does not delete server records; do not promise remote deletion until a verified server-side process exists.

## Audit Basis

Binding procedure:

- AXON `SOP: Secret Management in Agentic AI Development v3.0`, fetched 2026-07-18. No secret values were read, copied, logged, or written during this audit. Fly Secrets remains the approved canonical store for secrets used by the Fly.io workload; iOS/local credentials remain in Keychain.

Primary external sources:

- [Apple: App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple: App Review Guidelines — Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Apple: Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple: Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [OpenAI: API data controls](https://platform.openai.com/docs/models/default-usage-policies-by-endpoint)
- [OpenAI: Enterprise privacy](https://openai.com/enterprise-privacy/)
- [ElevenLabs: Zero Retention Mode](https://elevenlabs.io/docs/eleven-api/resources/zero-retention-mode)
- [Fly.io: Logging overview](https://fly.io/docs/monitoring/logging-overview/)

Detailed Apple research is in `research/2026-07-18-apple-app-privacy-requirements.md`.

## Actual Data Flows

| Data | Source and destination | Current retention | Apple assessment |
|---|---|---|---|
| Exact GPS coordinate and speed | Core Location to on-device state, map, policy, and Apple reverse geocoding | In memory during the app session. Release diagnostics no longer print exact coordinates or resolved addresses. No app code sends latitude/longitude to the RideHorizon proxy. | On-device processing does not require an App Privacy label entry. Apple collection by Apple services is not the developer's disclosure. |
| Town, county, region, and country | App to RideHorizon proxy to OpenAI for fact generation, only after explicit consent | The request omits street data and sends only the announced boundary and broader hierarchy. The proxy does not persist request bodies, but OpenAI may retain API inputs and outputs for up to 30 days by default. | **Coarse Location**, because retained place names are lower resolution than exact coordinates. App Functionality and Product Personalization. |
| Home country, home region, familiar regions, interests, and custom fact instructions | Stored in `UserDefaults`; sent through the proxy to OpenAI | On device until cleared/uninstalled; OpenAI may retain the resulting prompt for up to 30 days. The local fact-cache key also embeds this context. | Custom/free-form content is **Other User Content**. App Functionality and Product Personalization. Home/familiar place values are also location-derived context and must be described in the policy. |
| Generated fact and full announcement text | OpenAI response to app; app to proxy to ElevenLabs when Premium Voice is used, only after explicit consent | Generated facts and cache keys persist in `UserDefaults` for at most 30 days unless cleared sooner. The ElevenLabs request asks for Zero Retention Mode with `enable_logging=false`; the account entitlement still requires verification. | **Other User Content** and/or Coarse Location when the announcement contains rider-entered text or place names. App Functionality. |
| Generated MP3 audio | ElevenLabs to proxy to app | The app holds response bytes for playback. The request asks for Zero Retention Mode, but ElevenLabs account support must be confirmed before making a zero-retention claim. | Provider retention must be disclosed in the privacy policy. It is generated output rather than user-recorded Audio Data; do not select Audio Data unless future versions upload or record rider audio. |
| Random installation/device identifier and access credential | Generated/stored in iOS Keychain; device identifier sent to proxy | Current database stores the device identifier, token hash, optional operator label, creation, expiry, last-use, and revocation timestamps. Expired rows are not automatically deleted. | **Device ID**, linked to the device, for App Functionality/security. Not tracking. |
| App Attest key identifier, public key, receipt, counters, and sessions | Planned iOS/App Attest/proxy flow | Work in progress. The current iOS target has no App Attest entitlement and no App Attest client implementation. The uncommitted proxy session code references tables for which no migration is present in the audited checkout and contains placeholder proof validation. | When implemented, treat the stable app-instance/device record as **Device ID**, linked, App Functionality/security. Do not describe App Attest as live until the complete cryptographic flow is implemented and verified. |
| Proxy-use timestamp | Proxy database `last_used_at` tied to device credential/session | A scheduled cleanup deletes expired or revoked legacy credential records after 30 days. Deployment and production execution remain to be verified. | **Product Interaction**, linked to Device ID, App Functionality/security. |
| Client IP address | Fly edge/proxy request; in-memory rate-limit key | The application does not log the IP. Application rate-limit identities expire after the 60-second window and are pruned on subsequent traffic. Fly edge handling must still be confirmed. | Conservatively treat as **Other Data**, linked to a device/connection, App Functionality/security, until infrastructure non-retention is verified. |
| Request ID, route, status, duration, provider status, and response size | Proxy application logs to Fly.io | Fly.io searchable application logs are retained for about 7 days. Current application logs omit request bodies, device identifiers, IP addresses, and tokens. | **Other Diagnostic Data**, not linked, App Functionality. Do not select Analytics unless these events are later used for feature/audience analysis. |
| Ride history | In-memory SwiftUI array containing time, exact coordinate, address, and spoken phrase | Current session only; not written to a RideHorizon server. Release diagnostics do not print the exact values, and Clear Local Data removes the current session. | No label entry while on device only. Document that history is session-local. |
| Crash reports and analytics | No third-party crash or analytics SDK is present | Apple/TestFlight may process crash and usage information under Apple's own services. RideHorizon has no app-side retained crash pipeline in this checkout. | Do not select Crash Data or Analytics for the current app solely because Apple offers those services. Reassess if the developer downloads, exports, or separately retains such data. |

## Evidence in the Checkout

- `RideHorizon/LocationManager.swift` reads exact location and performs reverse geocoding on device; AI fact and premium-speech calls are gated by the saved consent decision.
- `RideHorizon/ContentView.swift` keeps ride logs in memory and provides consent withdrawal, an in-app privacy notice, and local-data clearing.
- `RideHorizon/PlaceFactRequest.swift` builds proxy requests and persistent cache keys from place hierarchy and rider context.
- `RideHorizon/PlaceFactCache.swift` stores fact text and context-derived keys in `UserDefaults` with a 30-day expiry and a clear operation.
- `RideHorizon/ProxyFactGenerator.swift` sends place hierarchy and rider context to the proxy, sends announcement text for speech, and attaches a stable device identifier.
- `RideHorizon/KeychainCredentialLoader.swift` stores the current token and generated device identifier in Keychain.
- `RideHorizon/OnboardingView.swift` names OpenAI and ElevenLabs, requires an Allow or Decline choice, preserves a non-AI path, and opens the in-app privacy notice.
- `fact-proxy/.../OpenAiService.java` sends place hierarchy, rider context, and custom instructions to OpenAI.
- `fact-proxy/.../ElevenLabsSpeechService.java` sends speech text only after app consent and requests `enable_logging=false`; the provider account entitlement remains an external verification item.
- `fact-proxy/.../RequestInstrumentationFilter.java` logs request IDs, paths, status, and duration without request content.
- `fact-proxy/.../RateLimitFilter.java` keys an in-memory rate limiter by user, device, or IP.
- `fact-proxy/.../PrivacyRetentionCleanup.java` and `V3__privacy_retention_indexes.sql` implement scheduled cleanup support for invite and legacy credential records.
- `RideHorizon/PrivacyInfo.xcprivacy` is included in the iOS target and declares no tracking plus the same-app `UserDefaults` required reason.

## App Store Connect Answers for the Current Behavior

Use these as the conservative answers for the behavior audited on 2026-07-18. Re-run the audit against the final archive and provider settings before publishing them.

### Data collection

Answer **Yes, we collect data from this app**.

Select these data types:

| App Store Connect data type | Purpose | Linked to user/device? | Used for tracking? |
|---|---|---:|---:|
| Coarse Location | App Functionality; Product Personalization | No, only if the proxy continues to strip the device identifier before provider retention and no logs/database join retained place content to the device. Otherwise Yes. | No |
| Other User Content | App Functionality; Product Personalization | No under the same pre-retention unlinking condition. Otherwise Yes. | No |
| Device ID | App Functionality | Yes | No |
| Product Interaction | App Functionality | Yes | No |
| Other Diagnostic Data | App Functionality | No | No |
| Other Data | App Functionality/security; includes retained IP-derived rate-limit data until non-retention is proven | Yes, conservatively | No |

Do not select, for the current app:

- Precise Location: exact coordinates are not sent to the RideHorizon proxy or retained by a non-Apple provider in the audited flow.
- Contact Information: the app has no account, name, email, address, or phone collection.
- Audio Data: the app does not record or upload rider audio.
- Crash Data: no RideHorizon or third-party crash pipeline is integrated.
- Advertising Data, Purchases, Financial Information, Health and Fitness, Contacts, Browsing History, Search History, or Sensitive Information.
- Tracking: no audited data is combined with other-company data for advertising/measurement or sent to a data broker.

### Important linked-data condition

The “not linked” answer for retained provider prompts is defensible only if all of these remain true:

1. the RideHorizon proxy does not retain request bodies, place content, speech text, or custom instructions;
2. those values are stripped of device, user, token, IP, and request identifiers before being sent to OpenAI or ElevenLabs;
3. RideHorizon does not later correlate provider history with device or proxy request records; and
4. provider configuration and contracts do not re-identify the end user.

If any condition fails, mark Coarse Location and Other User Content as linked.

## Remediation Status Before External TestFlight

### P0 — Blockers

1. **Completed in code:** explicit, optional, revocable AI-sharing consent gates OpenAI and ElevenLabs. Decline and withdrawal fall back to Names Only and Apple Voice.
2. **External action open:** publish a privacy policy at a stable HTTPS URL and add that public link in App Store Connect and the app. The in-app privacy notice is implemented.
3. **Completed in code:** `PrivacyInfo.xcprivacy` declares no tracking and the approved same-app `UserDefaults` reason. Validate it again in the final signed archive.
4. **Completed in code:** sensitive iOS diagnostics are compile-gated or replaced with value-free Release messages. Recheck the final archive and production logs.
5. **Code complete; account verification open:** ElevenLabs requests `enable_logging=false`. Confirm Zero Retention Mode is authorised for the production account before making that claim publicly.
6. **Code complete; deployment verification open:** scheduled cleanup and retention indexes cover invite and legacy credential records. Deploy the migration and verify production execution; extend cleanup to the separate App Attest/session work before that flow ships.

### P1 — Required for a defensible policy

1. **Completed in code:** fact requests omit street data and include only the announced boundary and broader hierarchy.
2. **Completed in code:** lower-priority place fields are omitted from OpenAI requests.
3. **Completed in code:** Clear Local Data cancels queued work, clears local cache/context/history/preferences/consent/diagnostics and local credentials, then returns to setup. It explicitly does not claim server deletion.
4. **External action open:** add a verified deletion-request process and stable privacy contact address before promising server deletion.
5. **Application code complete; infrastructure verification open:** rate-limit identities are purged on traffic and by a scheduled 60-second cleanup. Confirm Fly edge/network log handling.
6. Fix or remove the unfinished App Attest/session code before it can be considered part of a beta build. Real Apple attestation/assertion validation must replace placeholder proof checks; required migrations, entitlements, replay protection, counters, tests, and cleanup must exist.
7. Ensure secrets remain only in Keychain and Fly Secrets as required by the AXON SOP. Do not add token values to review notes, docs, logs, environment files, database plaintext fields, or tester instructions.

## Verification — 2026-07-18

- Privacy-focused iOS simulator tests passed on iPhone 17 / iOS 26.3.1, covering consent, withdrawal fallback, local clearing, hierarchy minimisation, and cache retention.
- An unsigned generic iOS Release build succeeded and contains `PrivacyInfo.xcprivacy` at the app-bundle root.
- The full fact-proxy Gradle test suite passed in a clean temporary checkout containing the privacy changes.
- The shared fact-proxy checkout cannot currently compile because separate unfinished App Attest source files contain syntax errors; those files were not changed by this privacy batch.
- Physical iPhone installation and Bluetooth/audio/background ride validation remain open because the configured device was not connected.

### P2 — Submission preparation

1. Generate Xcode's privacy report from the final archive and reconcile it with this audit and App Store Connect.
2. Confirm `ITSAppUsesNonExemptEncryption`/export-compliance answers for the final app. This is separate from the privacy label.
3. Update Beta App Review notes to describe AI consent, provider fallback, background location, and how the reviewer can exercise Names Only/Apple Voice without AI sharing.
4. Record the final data-retention schedule and processor list in the release checklist.
5. Re-run this audit whenever analytics, crash reporting, accounts, microphone/listening, POI search, or navigation handoff is added.

## Recommended Retention Schedule

Do not publish these periods until the backend and provider settings enforce them.

| Record | Recommended maximum |
|---|---|
| One-time challenges | Delete within 24 hours after expiry/consumption |
| Short-lived session tokens and token hashes | Delete within 7 days after expiry/revocation |
| Installation/App Attest public-key record | While the installation is active; delete within 30 days of a verified deletion request or 90 days after beta closure/inactivity |
| Current legacy device credentials | Delete within 30 days after expiry/revocation and remove the legacy system after App Attest migration |
| App request logs | 7 days; no location, content, IP, device ID, token, attestation object, or speech text |
| IP/device rate-limit keys | Active window plus a small bounded grace period; target no more than 10 minutes in memory |
| OpenAI request content | Provider default up to 30 days unless an approved lower-retention configuration is enabled |
| ElevenLabs TTS input/output | Zero retention or immediate deletion; otherwise use and disclose the verified account/provider period |
| On-device fact cache | Add 30-day expiry and user-triggered clearing |
| In-memory ride history | Current session only; clear on app termination or user request |

## Draft Privacy Policy

The following is a working draft. Replace every bracketed item, implement the promised controls, and obtain appropriate legal review before publication.

---

# RideHorizon Privacy Policy

Effective date: [YYYY-MM-DD]

RideHorizon is provided by [FULL LEGAL COMPANY NAME], referred to here as “we”, “us”, or “RideHorizon”. This policy explains how RideHorizon handles information when you use the iPhone app and its supporting services.

## What RideHorizon does

RideHorizon uses your device location to identify places you travel through and provide short, optional spoken place information. It is an audio place-awareness companion, not navigation, safety, or emergency software.

## Information processed on your device

RideHorizon processes your precise device location, speed, resolved place names, settings, rider preferences, recent ride history, and generated fact cache on your device. Precise latitude and longitude are not sent to the RideHorizon fact or speech service. Ride history is held for the current app session only. [CONFIRM AFTER REMEDIATION: Local cached facts and preferences can be cleared from Settings.]

Access credentials and the app-installation security identifier are stored in the iOS Keychain. The app does not contain or store our OpenAI or ElevenLabs API keys.

## Information sent from the app

When you enable AI-generated facts, RideHorizon sends the minimum required place information, such as town, county, region, and country, together with any fact interests or custom fact instructions you choose to provide. The service uses this information only to generate the requested place announcement.

When you enable Premium Voice, RideHorizon sends the announcement text to its speech service to generate audio.

The service also receives a random installation/security identifier, network information such as an IP address, and limited request information such as time, route, response status, and duration. These are used to authenticate the app, prevent abuse, apply limits, maintain reliability, and diagnose failures.

## AI services and your choice

RideHorizon clearly asks for permission before sharing location-derived information or rider content with third-party AI services. If you agree:

- OpenAI processes place information and optional rider preferences to generate facts.
- ElevenLabs processes announcement text to generate speech when Premium Voice is selected.

You can decline or withdraw this permission in Settings. If you decline, RideHorizon remains available with non-AI place-name announcements and Apple Voice. We do not use OpenAI or ElevenLabs for your requests after consent is withdrawn. [IMPLEMENT AND VERIFY BEFORE PUBLISHING.]

OpenAI states that API data is not used to train its models by default and may retain API inputs and outputs for up to 30 days for abuse monitoring, unless a different approved data-control setting applies. [CONFIRM ACCOUNT CONFIGURATION.]

ElevenLabs processes text and generated audio under its service terms. [INSERT THE VERIFIED RETENTION MODE AND PERIOD AFTER ZERO RETENTION OR DELETION IS IMPLEMENTED.]

## Other service providers

Our backend is hosted by Fly.io. Application logs contain limited technical request information and are retained for approximately [7 days]. [CONFIRM CLIENT IP HANDLING.] Apple provides iOS location, mapping, reverse-geocoding, App Attest, App Store, and TestFlight services under Apple's privacy terms.

We require service providers that process RideHorizon information to protect it consistently with this policy and applicable requirements. We do not sell personal information, share it with data brokers, or use it for cross-app advertising or advertising measurement.

## Retention

[INSERT THE IMPLEMENTED RETENTION TABLE.]

We retain information only for as long as needed to provide the service, protect it from abuse, meet legal obligations, and resolve disputes. Local information can be cleared in the app. Server-side installation and security records are deleted within [PERIOD] after a verified deletion request. Provider retention is described above.

## Your choices and rights

You can:

- deny or revoke Location Services in iOS Settings;
- decline or withdraw third-party AI sharing in RideHorizon Settings;
- select Apple Voice instead of Premium Voice;
- clear local RideHorizon data in Settings; and
- request access, correction, or deletion by contacting [PRIVACY EMAIL].

RideHorizon has no user account in this version. We may need limited information to verify that a deletion request relates to the correct installation. We will not ask you to send an access token, App Attest object, API key, or other secret.

## Security

We use transport encryption, iOS Keychain storage, short-lived or revocable access credentials, server-side access controls, rate limits, and restricted logging. No system is completely secure, but we design RideHorizon to minimize the information sent and retained.

## Children

RideHorizon is intended for adult motorcyclists and is not directed to children. We do not knowingly collect information from children.

## Changes

We may update this policy when RideHorizon changes. We will update the effective date and provide additional notice when required.

## Contact

[FULL LEGAL COMPANY NAME]

[REGISTERED OR BUSINESS ADDRESS]

[PRIVACY EMAIL]

[SUPPORT URL]

---

## App Store Connect Operator Checklist

Complete only after the final TestFlight candidate matches this audit:

1. Publish the implemented privacy policy at a stable HTTPS URL.
2. In App Store Connect, open App Privacy, add the policy URL, answer Yes to collection, and enter the audited data types/purposes/linkage/tracking answers.
3. Generate and inspect Xcode's privacy report for the final archive.
4. Confirm the bundled `PrivacyInfo.xcprivacy` is valid and present at the app-bundle root.
5. Verify AI consent from a clean install: decline must produce no OpenAI or ElevenLabs traffic; accept must enable the selected feature; withdrawal must stop later traffic.
6. Verify Release/TestFlight logs contain no coordinates, addresses, place content, custom text, speech text, device identifiers, IP addresses, tokens, or attestation material.
7. Verify server and provider retention settings against the published policy.
8. Update Beta App Review notes and submit the first external build only after the privacy and functional release gates pass.

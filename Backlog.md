# RideHorizon Delivery Ledger

This file is the canonical delivery ledger. Trello remains intake, Notion holds reusable SOPs, and `PROJECT.md` records only the last verified project state and current gate.

## In progress

### RH-001 — Harden the private TestFlight release candidate

- **Type:** Release and health increment.
- **Claimed by:** Codex on branch `codex/rh-001-testflight-hardening`.
- **Outcome:** The final iPhone candidate is safe and privacy-consistent for Apple review, passes deterministic checks, validates as a signed distribution archive, uploads to App Store Connect, and remains compatible with the live Fly proxy.
- **User/operator:** Rob can select the processed build for internal TestFlight testing without changing credentials or entering a tester token.
- **Included:** Reconcile the six failing iOS unit tests; prevent proxy-session provisioning before the rider enables optional AI features; add an explicit stationary-setup and non-interaction safety statement to onboarding; keep automatic restricted sessions and Apple Voice fallback working; update matching review metadata; build and install on the physical iPhone; independently review; archive, validate and upload when all local gates pass.
- **Non-goals:** Full App Attest enforcement, public App Store listing assets, payments, subscriptions, Android/iPad support, route guidance, or wider beta recruitment.
- **Dependencies:** `TESTFLIGHT_PRIVATE_BETA_PACK.md`, `APP_ATTEST_PROXY_ACCESS_PLAN.md`, `PRIVACY_AUDIT_2026-07-18.md`, `APP_STORE_CONNECT_TEST_INFORMATION.md`, the live Fly proxy, Cloudflare privacy URL, Apple signing, and App Store Connect access.
- **Risk:** Medium. The changes are small and reversible, but consent timing affects privacy behaviour and archive upload is an external side effect. No secret value may enter source, logs, commands, chat or Git.
- **Decision impact:** Record the consent-timing decision here and in the existing proxy-access plan. No ADR is required because on-demand provisioning preserves the existing API and trust boundaries and is easily reversible.
- **Delivery Risk Cube movement:** Hold functional breadth fixed; raise implementation fidelity from local device candidate to signed uploaded build; raise production-quality depth for privacy, safety, reliability and release operability.
- **Behavioural evidence:** A clean launch makes no RideHorizon proxy request before the AI choice; declining AI keeps facts local and uses Apple Voice; granting AI provisions automatically on first proxy-backed request; Test Mode starts at its first sample point; Premium Voice failure can use Apple Voice fallback; onboarding tells the rider to set up while stopped and not interact while moving.
- **Quality evidence:** No secret exposure; privacy manifest and policy remain consistent; Release diagnostics remain value-free; iPhone-only packaging remains intact; the live health, fact and speech paths remain available.
- **Deterministic verification:** `xcodebuild test -project RideHorizon.xcodeproj -scheme RideHorizon -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath DerivedData-TestFlight-Hardening -only-testing:RideHorizonTests` — expected result: `** TEST SUCCEEDED **` with zero failures.
- **Deterministic verification:** `./gradlew test` from `fact-proxy` — expected result: `BUILD SUCCESSFUL`.
- **Deterministic verification:** `xcodebuild build -project RideHorizon.xcodeproj -scheme RideHorizon -destination 'platform=iOS,id=00008150-000C70883E87401C' -derivedDataPath DerivedData-TestFlight-Hardening -allowProvisioningUpdates` — expected result: `** BUILD SUCCEEDED **`.
- **Independent evaluation:** A fresh review context checks the diff against this contract, Apple review risks, privacy boundaries and maintainability. Rob performs the final human TestFlight interaction check.
- **Stop condition:** Stop before upload if tests, signed validation, privacy evidence, live proxy checks or independent review fail. Stop and ask Rob if Apple authentication or a Keychain modal requires human interaction, or if implementation would change the approved proxy security boundary.
- **Gate:** Continue only to RH-002 after Apple reports the uploaded build processed successfully.
- **Evidence — 2026-07-31:** Full `RideHorizonTests` suite passed after final review fixes; fact-proxy Gradle tests passed; public health and privacy routes returned HTTP 200; automatic fallback session issuance, fact generation and speech generation returned HTTP 200; speech response was a valid 44,765-byte `audio/mpeg`; independent review found no blocking code issue; Release archive `0.12.3 (20260731.1857)` passed Xcode archive and local store validation.
- **Blocked gate — 2026-07-31:** The physical iPhone is unavailable to CoreDevice. The earlier `20260731.1942` archive upload stopped before transfer with `exportArchive Failed to Use Accounts`, and the reviewed reliability increment advances the current build to `20260731.2020`. Rob must reconnect/unlock the iPhone and refresh the Apple ID session in Xcode before this exact build can be archived, installed and uploaded.
- **Additional simulator evidence — 2026-07-31:** Replaced the skipped UI-test placeholders with a three-test clean-install suite. Before the recorded suite, the iPhone 16e simulator app was uninstalled and its permissions were reset. The suite verifies stationary-use copy, bounded layout, static Back-button position, absence of token/invite/API-key fields, all onboarding pages, privacy details and policy link, on-device-only consent, the real location permission prompt and main-screen launch. Visual inspection found and fixed horizontally clipped onboarding copy. A fresh iPhone 16e / iOS 26.3.1 run then exposed fixed-height landscape content; onboarding content is now adaptive and scrollable while navigation controls remain fixed. The landscape test waits for a width-greater-than-height app frame, verifies page-one scrolling and the longer AI-consent page, and reaches the privacy notice. Compact portrait and correctly oriented landscape screenshots are retained with the passing test results. Candidates `20260731.1857` and `20260731.1930` are superseded by `20260731.1942`.
- **Replacement archive — 2026-07-31:** Release archive `0.12.3 (20260731.1942)` passed Xcode's store validation. It is arm64/iPhone-only, contains the valid privacy manifest, declares no non-exempt encryption, has only location/audio background modes, has an opaque app icon, has matching binary/dSYM UUIDs, passes strict code-signature verification and exposes no credential-entry UI.
- **Observed infrastructure risk — 2026-07-31:** Fly is configured with `min_machines_running = 0`. A cold-start health request exceeded 20 seconds before the machine started; the next request returned HTTP 200. The app's health timeout is 6 seconds and fact/speech timeouts are 15 seconds, so the first optional AI request can fall back to Apple Voice after an idle period unless one machine is kept warm during the TestFlight window.
- **Reliability increment authorised — 2026-07-31:** Keep one Fly proxy machine warm for the private-beta window and replace the conflicting 15-second client limits with one coherent rider-network policy. Fact and Premium Voice operations have a 60-second wall-clock ceiling; each proxy attempt may wait up to 35 seconds so the proxy's 30-second OpenAI/ElevenLabs deadline can complete; transient connection failures and HTTP 408/502/503/504 may retry after 3 and 10 seconds while permanent 4xx responses do not retry. A structured Premium Voice failure retries only the generic transport/provider category, not authentication, account-capacity or throttling categories. Automatic session provisioning uses the same transient-failure classification within a shorter 30-second ceiling. Cancellation must stop retry/backoff promptly, and a superseded fact or speech request must never produce delayed audio or Apple fallback. Existing 401 session invalidation/reprovisioning remains compatible with the deployed proxy.
- **Reliability acceptance evidence — 2026-07-31:** Focused tests prove recovery after transient network and gateway failures, no retry for permanent/capacity failures, cancellation during backoff, prompt wall-clock expiry even when session provisioning ignores cancellation, preservation across street-only geocoder churn, boundary-priority preservation and suppression of superseded Premium Voice fallback. The complete iOS unit target, generic iPhone build, proxy Gradle suite and OpenAPI parse pass. Two independent reviews found no remaining blocker in commit `1665bac`. Fly production version 38 preserves `https://motoguide-fact-proxy.fly.dev`, sets `min_machines_running = 1`, and reached `started`; live health returned `ok`, automatic restricted session issuance succeeded, facts returned HTTP 200 `application/json` with 259 bytes, and ElevenLabs returned HTTP 200 `audio/mpeg` with 34,316 bytes. The unavailable physical iPhone remains the only unrun device-install check for this increment.

## Ready

### RH-002 — Internal TestFlight smoke and external beta submission

- **Type:** Release and operations increment.
- **Outcome:** The exact processed build passes a clean internal TestFlight smoke test and is submitted for external TestFlight review with accurate metadata.
- **User/operator:** Rob and the first 3–5 named private testers.
- **Boundaries:** Internal group, clean TestFlight install, onboarding, consent decline/grant, Test Mode, facts, Premium Voice, Apple fallback, privacy link, App Privacy publication check, external group and review submission. No public TestFlight link and no public App Store submission.
- **Dependencies:** RH-001 Done and the uploaded build in `Ready to Submit` or equivalent processed state.
- **Risk:** Medium because the final approval and App Store Connect declarations require Rob's legal and account-holder judgement.
- **Decision impact:** No ADR. App Store Connect declarations remain Rob's responsibility where legal confirmation is required.
- **Delivery Risk Cube movement:** Raise implementation fidelity to the actual TestFlight distribution path and production-quality depth through independent clean-install evidence.
- **Behavioural evidence:** A tester with no prior Keychain state can use the core experience without credentials or motorcycle hardware.
- **Quality evidence:** The exact TestFlight binary, public privacy page and live backend agree with the saved App Store Connect declarations.
- **Deterministic verification:** App Store Connect displays the processed build without `Invalid Binary` or `Missing Compliance`; TestFlight installs and launches it on the target iPhone.
- **Independent evaluation:** Rob completes the human smoke test; Apple performs TestFlight App Review.
- **Stop condition:** Stop submission on any crash, credential prompt, broken policy link, unavailable AI path, inaccurate declaration or unresolved safety issue.
- **Gate:** Submit for external review, revise if rejected, or pause if real-device evidence is unsafe.

## Shaping

- Full App Attest enforcement after the first private beta.
- Public App Store metadata, screenshots, support page, regional declarations and launch hardening.

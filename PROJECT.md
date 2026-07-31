# RideHorizon Project State

Last verified: 2026-07-31

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon `0.12.3 (20260731.2020)` is the current source and device-build candidate. It adds the reviewed rider-network policy: 35-second attempts, a 60-second fact/Premium Voice ceiling, transient retries after 3 and 10 seconds, prompt cancellation, boundary-priority preservation and stale-audio suppression. The complete iOS unit target, the earlier three-test clean-install UI suite, the fact-proxy Gradle suite and the Cloudflare edge suite pass; a generic iPhone build also passes. Fly production version 38 keeps one machine warm at the existing hostname. On 2026-07-31 its health endpoint returned `ok`, automatic session issuance succeeded, OpenAI facts returned HTTP 200 JSON, and ElevenLabs returned HTTP 200 `audio/mpeg` with 34,316 bytes. The validated `20260731.1942` Release archive is now superseded by these source changes, so `20260731.2020` still requires a signed archive, physical-iPhone install and App Store Connect upload.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, and a validated layout-corrected Release archive exist; physical-device installation, App Store Connect processing and TestFlight installation remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, provider fallback and green automated checks are in place. Real-world background location, battery and Bluetooth evidence remains the largest gap.

## Current gate

Complete RH-001 in `Backlog.md`. When available, reconnect and unlock the target iPhone. Refresh the Apple ID session in Xcode, create and validate the signed `20260731.2020` archive, install that exact build, then retry the App Store Connect upload. Do not start RH-002 until Apple finishes processing this build.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- Background location, battery and Bluetooth behaviour require evidence from the exact TestFlight build and real rides.

## Next outcomes

1. RH-001: hardened, reviewed and uploaded release candidate.
2. RH-002: clean internal TestFlight smoke and external review submission.
3. After the milestone gate, decide whether to continue to App Attest hardening or pause for private-beta evidence.

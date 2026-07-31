# RideHorizon Project State

Last verified: 2026-07-31

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon `0.12.3 (20260731.1857)` is the current reviewed hardening candidate. The public privacy policy and Cloudflare-to-Fly health path are live. Automatic restricted sessions, OpenAI facts and ElevenLabs speech passed a fresh production check. The full iOS unit suite and fact-proxy Gradle suite pass. Independent review found no blocking code issue, and the Release archive passed Xcode's local store validation. The exact build still requires a physical-iPhone install and App Store Connect upload; both are waiting on local device/account availability.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services and a validated Release archive exist; physical-device installation of this exact build, App Store Connect processing and TestFlight installation remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, provider fallback and green automated checks are in place. Real-world background location, battery and Bluetooth evidence remains the largest gap.

## Current gate

Complete RH-001 in `Backlog.md`. Reconnect and unlock the target iPhone, refresh the Apple ID session in Xcode, install the exact build, then retry the App Store Connect upload. Do not start RH-002 until Apple finishes processing this build.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Background location, battery and Bluetooth behaviour require evidence from the exact TestFlight build and real rides.

## Next outcomes

1. RH-001: hardened, reviewed and uploaded release candidate.
2. RH-002: clean internal TestFlight smoke and external review submission.
3. After the milestone gate, decide whether to continue to App Attest hardening or pause for private-beta evidence.

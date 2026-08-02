# RideHorizon Project State

Last verified: 2026-08-02

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon `0.12.3 (20260802.2254)` is the current source and device-build candidate. A fresh install now starts with Test Mode off so live location updates are processed; an explicit saved Test Mode choice still persists. Both focused regression tests and the complete `RideHorizonTests` target passed on the physical iPhone: 115 tests, zero failures. The complete app and test targets compile, the unsigned generic-iPhone Release build passes, and the normal signed candidate installed and launched on `Robert’s iPhone 17`. The previously verified rider-network, proxy, Cloudflare and live-service evidence remains unchanged. This exact build still requires a signed Release archive and App Store Connect upload.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, a validated earlier Release archive, and installation/launch of the current signed development candidate exist; the current Release archive, App Store Connect processing, TestFlight installation and manual ride smoke test remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, provider fallback and green automated checks are in place. Real-world background location, battery and Bluetooth evidence remains the largest gap.

## Current gate

Complete RH-001 in `Backlog.md`. Create and validate the signed `20260802.2254` Release archive, upload it to App Store Connect, and wait for processing. Do not start RH-002 until Apple finishes processing this build.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- Background location, battery and Bluetooth behaviour require evidence from the exact TestFlight build and real rides.

## Next outcomes

1. RH-001: hardened, reviewed and uploaded release candidate.
2. RH-002: clean internal TestFlight smoke and external review submission.
3. After the milestone gate, decide whether to continue to App Attest hardening or pause for private-beta evidence.

# RideHorizon Project State

Last verified: 2026-08-04

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon `0.12.4 (20260804.0246)` is the current private-TestFlight release candidate. All 177 iOS tests passed on the physical iPhone, the fact-proxy suite passed, and the live Fly health, automatic-session, fact and Premium Voice paths returned HTTP 200. The exact Release archive passed Apple Distribution signing, server-side validation, strict IPA signature and entitlement checks, privacy-manifest validation and binary/dSYM UUID matching. It is iPhone-only, contains no test or calibration artefacts, is installed and launches on the target iPhone, and Apple accepted its upload for processing. App Store Connect processing and exact-Internal-TestFlight human evidence remain outstanding.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, installation/launch of the current signed development candidate, and an exact uploaded Release archive exist. The archive has passed cloud-managed Apple Distribution signing, strict local verification, Apple server-side validation and upload. App Store Connect processing, TestFlight installation and the manual ride smoke test remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, bounded ride/audio lifecycles, provider fallback and green automated checks are in place. Stationary music interruption/restoration, Bluetooth, background-end and real-world battery evidence still define the release gate.

## Current gate

**VERIFY — App Store Connect processing and exact-build evidence.** Confirm that Apple finishes processing `0.12.4 (20260804.0246)`, add it to the internal group, install that exact TestFlight binary, then run the mandatory stationary and field checks. Do not invite external testers until the release gate is satisfied.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- The 10-minute/two-minute background inactivity behaviour still needs physical evidence with the screen locked.
- Announcement-scoped interruption and restoration still need stationary music and Bluetooth-headset evidence; automated checks cannot assess subjective loudness or sudden perceived volume changes.
- iOS exposes audio-session events and output-volume snapshots, but not reliable external-app identity or control of system volume; coexistence still requires physical evidence.
- Background location, battery and Bluetooth behaviour require evidence from the exact replacement TestFlight build and real rides.

## Next outcomes

1. Confirm that App Store Connect reports build `0.12.4 (20260804.0246)` as processed successfully.
2. Add the build to the internal group and install the exact TestFlight binary.
3. Complete the stationary, road, background, inactivity, audio, network and power evidence before external review submission.

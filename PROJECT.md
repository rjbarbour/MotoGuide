# RideHorizon Project State

Last verified: 2026-08-04

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon `0.12.3 (20260804.0231)` implements the authorised phase-one Premium Voice baseline in the existing processor: per-announcement window-gated active-speech RMS adjustment, 90 Hz high-pass, +2 dB presence, Light compression and the existing headroom-preserving sample limiter. Compatible multi-file TTS chunks are joined before DSP so the announcement has continuous processing state. Focused synthetic, real bundled-fixture and multi-chunk tests passed, followed by the complete `RideHorizonCalibration` unit target on the iPhone 17 simulator. Signed Debug and unsigned Release generic-iPhone builds passed. A simulator crash report was traced to an obsolete test that indexed the now-merged second buffer; the corrected whole-utterance regression and full suite passed. The physical iPhone was not connected, so this build has not yet been installed or heard through the phone/headset.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, installation/launch of the current signed development candidate, and an exact current Release archive exist. The archive has passed cloud-managed Apple Distribution signing, strict local verification and Apple server-side validation. Build upload, App Store Connect processing, TestFlight installation and the manual ride smoke test remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, bounded ride/audio lifecycles, provider fallback and green automated checks are in place. Stationary music interruption/restoration, Bluetooth, background-end and real-world battery evidence still define the release gate.

## Current gate

**VERIFY — Premium Voice listening gate.** Install `0.12.3 (20260804.0231)` on the physical iPhone, then compare ordinary Premium Voice announcements with and without YouTube Music through the phone and helmet headset. Check intelligibility, distortion and music restoration. Do not tune Google Maps, archive or upload until this bounded baseline is heard on the target device.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- The 10-minute/two-minute background inactivity behaviour still needs physical evidence with the screen locked.
- Announcement-scoped interruption and restoration still need stationary music and Bluetooth-headset evidence; automated checks cannot assess subjective loudness or sudden perceived volume changes.
- iOS exposes audio-session events and output-volume snapshots, but not reliable external-app identity or control of system volume; coexistence still requires physical evidence.
- Background location, battery and Bluetooth behaviour require evidence from the exact replacement TestFlight build and real rides.

## Next outcomes

1. Connect and unlock the physical iPhone, install `0.12.3 (20260804.0231)`, and run the stationary Premium Voice check through the phone output and helmet headset, with and without YouTube Music.
2. Accept, revise or reject the phase-one baseline from intelligibility, distortion and restoration evidence; use the internal Calibration build only if a bounded comparison is still needed.
3. Install the exact TestFlight binary and complete the road, background, inactivity, audio, network and power evidence before external review submission.

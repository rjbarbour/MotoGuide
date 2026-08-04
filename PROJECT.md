# RideHorizon Project State

Last verified: 2026-08-03

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon internal calibration candidate `0.12.3 (20260803.2345)` makes system output volume live, exposes wider 6 dB Candidate B choices, proves Strong compression changes rendered speech, and provides an explicit internal-only switch for using the current Candidate B profile during normal Premium Voice ride evaluation. Pressing Candidate B or saving it does not enable the switch. The override persists locally only in the Calibration build, is visible on the main screen and cannot be changed or disabled while a ride is active; the production profile remains unchanged. The Calibration target passed 189 physical-device tests and normal Debug passed 173. Representative and maximum offline renders remained at or below −2.1 dBFS true peak. The unsigned normal Release build succeeded and contains no calibration resources, UI labels, navigation entry or override persistence key. The previously Apple-validated `20260803.0032` archive remains superseded and must not be uploaded.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, installation/launch of the current signed development candidate, and an exact current Release archive exist. The archive has passed cloud-managed Apple Distribution signing, strict local verification and Apple server-side validation. Build upload, App Store Connect processing, TestFlight installation and the manual ride smoke test remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, bounded ride/audio lifecycles, provider fallback and green automated checks are in place. Stationary music interruption/restoration, Bluetooth, background-end and real-world battery evidence still define the release gate.

## Current gate

**VERIFY — Speech Calibration and road-evaluation gate.** Internal candidate `0.12.3 (20260803.2345)` must first be adjusted while stationary under Settings → Developer → Speech Calibration. If a Candidate B is worth road testing, explicitly enable **Use Candidate B for normal Premium Voice**, leave the lab and run the normal Premium Voice path with music. This is an internal runtime override, not production-profile promotion. Do not tune Google Maps, archive or upload until Rob accepts or rejects the candidate after the ride.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- The 10-minute/two-minute background inactivity behaviour still needs physical evidence with the screen locked.
- Announcement-scoped interruption and restoration still need stationary music and Bluetooth-headset evidence; automated checks cannot assess subjective loudness or sudden perceived volume changes.
- iOS exposes audio-session events and output-volume snapshots, but not reliable external-app identity or control of system volume; coexistence still requires physical evidence.
- Background location, battery and Bluetooth behaviour require evidence from the exact replacement TestFlight build and real rides.

## Next outcomes

1. Run the stationary Speech Calibration gate on `0.12.3 (20260803.2345)` through the phone output and helmet headset, with and without YouTube Music.
2. If useful, explicitly enable the internal Candidate B normal-announcement override and evaluate it during a normal ride with music; then accept, revise or reject it.
3. Install the exact TestFlight binary and complete the road, background, inactivity, audio, network and power evidence before external review submission.

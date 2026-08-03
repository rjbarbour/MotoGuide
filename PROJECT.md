# RideHorizon Project State

Last verified: 2026-08-03

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon internal calibration candidate `0.12.3 (20260803.2300)` is installed and launched on the physical iPhone. It retains the explicit ride lifecycle and event-driven music interruption/restoration behaviour from `20260803.2218`. The production Premium Voice profile is unchanged. An internal-only Speech Calibration Lab now compares that baseline with bounded local candidate processing using three immutable Premium Voice fixtures and the live production Apple Voice path. Every fixture play reloads original bundled bytes, makes no proxy request and uses the existing announcement audio-session lifecycle. Experimental profiles remain separate from production. Calibration-specific diagnostics retain only fixture/profile identifiers, processing measurements and terminal outcomes. The Calibration target passed 185 physical-device tests and the normal Debug target passed 173; representative and extreme offline renders remained at or below −2.1 dBFS true peak. The unsigned normal Release build succeeded and contains no calibration resources, UI labels, navigation entry or persistence key. The previously Apple-validated `20260803.0032` archive remains superseded and must not be uploaded.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, installation/launch of the current signed development candidate, and an exact current Release archive exist. The archive has passed cloud-managed Apple Distribution signing, strict local verification and Apple server-side validation. Build upload, App Store Connect processing, TestFlight installation and the manual ride smoke test remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, bounded ride/audio lifecycles, provider fallback and green automated checks are in place. Stationary music interruption/restoration, Bluetooth, background-end and real-world battery evidence still define the release gate.

## Current gate

**VERIFY — Speech Calibration human gate.** Internal candidate `0.12.3 (20260803.2300)` is installed and launched. While stopped, Rob must open Settings → Developer → Speech Calibration, start YouTube Music manually and compare Current A with Candidate B for Place Name, Boundary and Short Fact through the phone and helmet headset. Judge intelligibility, harshness/clipping and the transition when iOS restores music. Save/export a candidate only if useful. Do not promote a profile, tune Google Maps, archive or upload until Rob accepts or rejects the calibration approach.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- The 10-minute/two-minute background inactivity behaviour still needs physical evidence with the screen locked.
- Announcement-scoped interruption and restoration still need stationary music and Bluetooth-headset evidence; automated checks cannot assess subjective loudness or sudden perceived volume changes.
- iOS exposes audio-session events and output-volume snapshots, but not reliable external-app identity or control of system volume; coexistence still requires physical evidence.
- Background location, battery and Bluetooth behaviour require evidence from the exact replacement TestFlight build and real rides.

## Next outcomes

1. Run the stationary Speech Calibration gate on `0.12.3 (20260803.2300)` through the phone output and helmet headset, with and without YouTube Music.
2. Record whether Current A or a saved Candidate B is accepted. Only then promote the chosen profile and repeat the required audio tests.
3. Install the exact TestFlight binary and complete the road, background, inactivity, audio, network and power evidence before external review submission.

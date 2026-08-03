# RideHorizon Project State

Last verified: 2026-08-03

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon `0.12.3 (20260803.2218)` is installed and launched on the physical iPhone. It opens idle, starts and ends continuous work only through explicit **Start ride / End ride** actions, and retains the bounded inactivity lifecycle. During this Debug validation campaign, Test Mode defaults on unless the user has explicitly changed it; Release/TestFlight still defaults off. Road plus Names Only are applied once when this Debug campaign starts, without overwriting later explicit choices. Both manual Test Mode controls enter the same `advanceTestLocation()` pipeline. The enabled music setting activates a non-mixing audio session immediately before actual Apple or Premium Voice playback, temporarily interrupting other audio, then deactivates with notification so iOS can resume it. No preflight primary-audio hint or timer delays an announcement. Genuine observed interruption/secondary-audio intervals pause speech and restart it immediately only after every overlapping interval ends. Premium Voice is decoded off-main and peak-normalised by at most +6.02 dB using one gain across the announcement. A privacy-safe private-beta diagnostic chain correlates place lookup through fact generation, TTS, audio readiness, playback, interruption, cancellation, restart and release, and adds coarse public network-path snapshots only at proxy-backed request stages. It retains no text, coordinates, carrier identity, IP addresses or credentials. The previously Apple-validated `20260803.0032` archive is superseded and must not be uploaded.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, installation/launch of the current signed development candidate, and an exact current Release archive exist. The archive has passed cloud-managed Apple Distribution signing, strict local verification and Apple server-side validation. Build upload, App Store Connect processing, TestFlight installation and the manual ride smoke test remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, bounded ride/audio lifecycles, provider fallback and green automated checks are in place. Stationary music interruption/restoration, Bluetooth, background-end and real-world battery evidence still define the release gate.

## Current gate

**VERIFY — YouTube Music gate.** Increment 1 revision is installed and launched as `0.12.3 (20260803.2218)`. All 172 physical-device tests passed, signed Debug and Release builds succeeded, and the live Fly health endpoint returned `ok`; the earlier live fact and Premium Voice smoke remained compatible because this batch did not change the proxy contract. Rob must now verify one Apple Voice and one Premium Voice announcement with YouTube Music through the phone output, then repeat the passing case through the helmet headset. Judge the revised location-to-voice latency, speech loudness and the transition when iOS resumes music. Do not tune Google Maps, archive or upload until this gate is accepted.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- The 10-minute/two-minute background inactivity behaviour still needs physical evidence with the screen locked.
- Announcement-scoped interruption and restoration still need stationary music and Bluetooth-headset evidence; automated checks cannot assess subjective loudness or sudden perceived volume changes.
- iOS exposes audio-session events and output-volume snapshots, but not reliable external-app identity or control of system volume; coexistence still requires physical evidence.
- Background location, battery and Bluetooth behaviour require evidence from the exact replacement TestFlight build and real rides.

## Next outcomes

1. Run the YouTube Music gate on `0.12.3 (20260803.2218)`: Apple Voice and Premium Voice through the phone output, then the passing case through the helmet headset.
2. If it passes, complete the remaining stationary checks, archive and validate this replacement code, then upload it for Internal TestFlight.
3. Install the exact TestFlight binary and complete the road, background, inactivity, audio, network and power evidence before external review submission.

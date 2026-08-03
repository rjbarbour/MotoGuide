# RideHorizon Project State

Last verified: 2026-08-03

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon `0.12.3 (20260803.0032)` is the current release candidate. It now opens idle, starts and ends continuous work only through explicit **Start ride / End ride** actions, prompts after 10 minutes without confidence-adjusted 50-metre movement, and automatically ends after the two-minute grace. Expired prompts cannot resume a stale ride; late location callbacks and place-lookup results cannot restart or mutate work after End ride; and pre-prompt place lookups cannot become valid after Continue. Audio-session ownership begins at actual Apple or Premium Voice playback and ends on finish, cancellation, failure, interruption or ride end, with bounded retry if system deactivation fails. A privacy-safe Release diagnostic buffer is bounded by 2,000 events, seven days and 1 MiB, persists through serialised coalesced background writes, is excluded from backups, and can be viewed, exported or cleared under Advanced. The complete `RideHorizonTests` target passed on the physical iPhone: 144 tests, zero failures. The signed development app built, installed and launched on `Robert’s iPhone 17`. Xcode then re-signed the exact archive with a cloud-managed Apple Distribution certificate and TestFlight-enabled App Store profile. Apple reported **App validation complete** at `2026-08-03T01:44:00+01:00`; the exported IPA passes strict signature verification with `get-task-allow=false`. The live automatic session, fact and ElevenLabs speech chain returned HTTP 200, including a valid 38,078-byte `audio/mpeg` response; the product, support and privacy URLs returned HTTP 200 through the reviewed Cloudflare worker.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, installation/launch of the current signed development candidate, and an exact current Release archive exist. The archive has passed cloud-managed Apple Distribution signing, strict local verification and Apple server-side validation. Build upload, App Store Connect processing, TestFlight installation and the manual ride smoke test remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, bounded ride/audio lifecycles, provider fallback and green automated checks are in place. Stationary music-ducking, Bluetooth, background-end and real-world battery evidence still define the release gate.

## Current gate

**VERIFY.** RH-003 and the deterministic part of RH-004 are implemented in release candidate `0.12.3 (20260803.0032)`. Its App Store-signed IPA exists and has passed both strict local verification and Apple server-side validation. Rob must complete `TF-SESSION-01` to `TF-SESSION-03` and `TF-AUDIO-01` to `TF-AUDIO-02` while stationary. Do not upload until those five perceptual checks pass. Then upload the already validated archive, install it through Internal TestFlight, and complete the remaining field evidence before external submission.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- The 10-minute/two-minute background inactivity behaviour still needs physical evidence with the screen locked.
- Announcement-scoped ducking and restoration still need stationary music and Bluetooth-headset evidence; automated checks cannot assess subjective loudness or sudden perceived volume changes.
- iOS exposes audio-session events and output-volume snapshots, but not reliable external-app identity or control of system volume; coexistence still requires physical evidence.
- Background location, battery and Bluetooth behaviour require evidence from the exact replacement TestFlight build and real rides.

## Next outcomes

1. Run the five mandatory stationary checks on `0.12.3 (20260803.0032)` and record evidence.
2. After the stationary checks pass, upload the already distribution-signed and Apple-validated exact archive.
3. Install through Internal TestFlight and complete the road, background, inactivity, audio, network and power evidence before external review submission.

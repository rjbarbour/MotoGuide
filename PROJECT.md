# RideHorizon Project State

Last verified: 2026-08-03

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon `0.12.3 (20260803.2016)` is the current physical-device candidate. It opens idle, starts and ends continuous work only through explicit **Start ride / End ride** actions, prompts after 10 minutes without confidence-adjusted 50-metre movement, and automatically ends after the two-minute grace. Expired prompts cannot resume a stale ride; late location callbacks and place-lookup results cannot restart or mutate work after End ride; and pre-prompt place lookups cannot become valid after Continue. Audio-session ownership begins at actual Apple or Premium Voice playback and ends on finish, cancellation, failure, interruption or ride end, with bounded retry if system deactivation fails. Continuous music now causes only a bounded three-second announcement yield, while genuine audio interruptions remain deferred until iOS ends them. A privacy-safe Release diagnostic buffer is bounded by 2,000 events, seven days and 1 MiB, persists through serialised coalesced background writes, is excluded from backups, and can be viewed, exported or cleared under Advanced. The complete `RideHorizonTests` target passed on the physical iPhone, and the signed development app built, installed and launched on `Robert’s iPhone 17`. The live automatic session, fact and ElevenLabs speech chain returned HTTP 200, including a valid 40,586-byte `audio/mpeg` response; the product, support and privacy URLs returned HTTP 200 through the reviewed Cloudflare worker. The previously Apple-validated `20260803.0032` archive is superseded and must not be uploaded.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, installation/launch of the current signed development candidate, and an exact current Release archive exist. The archive has passed cloud-managed Apple Distribution signing, strict local verification and Apple server-side validation. Build upload, App Store Connect processing, TestFlight installation and the manual ride smoke test remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, bounded ride/audio lifecycles, provider fallback and green automated checks are in place. Stationary music-ducking, Bluetooth, background-end and real-world battery evidence still define the release gate.

## Current gate

**VERIFY.** The failed competing-audio path was reproduced and corrected in `0.12.3 (20260803.2016)`. Continuous music now causes a bounded three-second yield; genuine interruptions remain deferred until iOS ends them. The duplicate centre brand is gone and the toolbar exposes content, phrase, audio-wait, voice-preparation and speaking states. Three targeted physical-iPhone tests and the complete unit suite passed, and the live proxy returned a fact plus 40,586 bytes of `audio/mpeg`. The corrected build is installed and launched on Rob's iPhone. Repeat all five stationary checks, especially YouTube Music ducking and restoration, before archiving or uploading.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- The 10-minute/two-minute background inactivity behaviour still needs physical evidence with the screen locked.
- Announcement-scoped ducking and restoration still need stationary music and Bluetooth-headset evidence; automated checks cannot assess subjective loudness or sudden perceived volume changes.
- iOS exposes audio-session events and output-volume snapshots, but not reliable external-app identity or control of system volume; coexistence still requires physical evidence.
- Background location, battery and Bluetooth behaviour require evidence from the exact replacement TestFlight build and real rides.

## Next outcomes

1. Repeat the five stationary checks on `0.12.3 (20260803.2016)` and record perceptual evidence for YouTube Music ducking, speech loudness and restoration.
2. If they pass, archive and validate this replacement code, then upload it for Internal TestFlight.
3. Install the exact TestFlight binary and complete the road, background, inactivity, audio, network and power evidence before external review submission.

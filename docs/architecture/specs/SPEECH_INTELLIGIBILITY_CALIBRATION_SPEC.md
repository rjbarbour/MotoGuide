# RideHorizon Speech Intelligibility And Calibration Specification

Date: 2026-08-03

Status: **Ready for delta assessment and a bounded calibration probe. This document does not claim that existing speech processing is absent. Audit the current implementation first, implement only the delta, and stop at the human calibration gate before promoting a new production profile.**

Related authority:

- `Backlog.md`, work item `RH-004`.
- `docs/architecture/plans/AUDIO_INTEROPERABILITY_VALIDATION_PLAN.md`, Increment 1.
- `docs/operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md`, especially `TF-AUDIO-01`, `TF-AUDIO-02` and `TF-AUDIO-05`.

## Goal

Make short RideHorizon announcements intelligible through a Bluetooth helmet headset in stopped, urban and motorway-like noise without changing system volume, clipping speech, leaving another app suppressed or requiring a rebuild for each tuning attempt.

The immediate deliverable is a developer-only Speech Calibration Lab that uses fixed bundled Premium Voice fixtures and the live production Apple Voice path. It must let Rob compare the current production processing with bounded candidate profiles on the physical iPhone while YouTube Music is already playing.

The stop condition is human selection or rejection of a candidate profile. Do not automatically promote an experimental profile into normal RideHorizon playback merely because automated tests pass.

**2026-08-04 bounded production amendment:** Rob separately authorised the conventional phase-one processing baseline after the calibration discussion. This is not promotion of a saved Candidate B profile. The authorised baseline uses per-announcement window-gated active-speech RMS adjustment, a conservative 90 Hz high-pass, +2 dB presence, Light compression and the existing sample limiter. The RMS heuristic must not be labelled LUFS, P.56 or true peak, and the result returns to human listening rather than automatic further tuning.

## Known baseline to verify

The checkout inspected on 2026-08-03 already contains:

- Apple speech with `AVSpeechUtterance.volume = 1`.
- Premium Voice MP3 decoding off the main actor.
- One gain calculation across every speech-audio chunk in an announcement.
- `SpeechAudioPeakNormaliser` with maximum 2×/+6.02 dB gain and a −2 dBFS sample-peak target.
- `AVAudioEngine`-based Premium Voice playback.
- Tests for bounded peak gain, real-MP3 preparation and audio-session release.
- A measured raw Premium Voice sample at approximately −24.1 LUFS integrated and −8.2 dBFS true peak.

The implementing session must inspect the actual branch and working tree rather than recreate these components. Preserve correct existing behaviour and tests. Record the delta between this specification and the inspected implementation before changing code.

## Inspected implementation delta — 2026-08-03

The active branch already implements and tests the baseline above. `SpeechAudioPeakNormaliser` calculates one non-attenuating gain for the complete announcement, bounded to 2×/+6.02 dB and a −2 dBFS sample-peak target. `PremiumAudioPreparer` decodes MP3 audio off the main actor, applies that shared gain to every decoded segment and remains cancellable. `NormalisedPremiumAudioPlayer` already uses `AVAudioEngine`, while `LocationManager` owns the existing announcement-scoped audio-session acquisition and terminal release path. These components are retained rather than recreated.

The bounded probe must add only the missing delta:

- one reusable profile-driven Premium Voice processing boundary used by normal production preparation and calibration playback;
- deterministic high-pass, presence, compression, output-gain and final sample-peak-ceiling processing while preserving the current production profile exactly;
- three immutable proxy-generated Premium Voice fixtures plus a non-secret integrity/provenance manifest;
- an internal-compilation-only calibration controller and Settings screen, including ride-active refusal, A/B playback, local experimental-profile persistence and JSON export;
- calibration-specific privacy-safe diagnostic values and focused cancellation/release tests; and
- a dedicated internal build path plus deterministic proof that normal Release contains no lab entry, calibration-only strings, manifest or fixtures.

No new external DSP dependency, proxy contract, cache, Google Maps policy or production processing profile is required.

## Decisions

1. Embed the calibration lab in RideHorizon so it exercises the real production audio session, Bluetooth route, processing implementation and music-restoration path.
2. Expose it only in a dedicated internal calibration build. Exclude its UI, source entry points, strings and fixture audio from normal Release/TestFlight binaries.
3. Bundle three immutable raw Premium Voice MP3 fixtures. Generate each once through the existing authenticated Fly speech proxy, then check the returned speech audio into a calibration-only resource location.
4. Do not add or depend on a fact cache, speech-audio cache, Fly Volume, Redis or other caching layer for this lab.
5. Generate Apple Voice comparisons live through the existing production Apple speech path. Do not cache Apple speech or route it through the Premium Voice processor during this increment.
6. Process each Premium fixture again from its original bundled bytes on every play. Never process an already processed buffer.
7. Keep the current production profile as the A baseline. Candidate processing remains experimental until Rob selects a profile at the physical calibration gate.
8. Keep raw engineering controls internal. A later customer setting, if justified, should use a small Normal/Louder-style choice rather than exposing LUFS, EQ or compressor controls.

These decisions are reversible and local to `RH-004`; no ADR is required unless implementation introduces a new external DSP dependency or moves processing across the client/server boundary.

## Terminology

Use the terms defined in `AGENTS.md`:

- **Announcement text** is the text prepared for the rider.
- **Text-to-speech (TTS)** converts announcement text into speech.
- **Synthesised speech audio**, shortened to **speech audio**, is the audio returned by ElevenLabs or produced by Apple Voice.
- **MP3 audio** describes the encoded Premium Voice fixture format, not the general product concept.

## Calibration fixtures

Generate these exact announcement texts with the currently configured Fly proxy, ElevenLabs voice, model and output format:

| Fixture | Announcement text | Purpose |
|---|---|---|
| `premium-place-name.mp3` | `Cheltenham.` | Very short place-name intelligibility and onset behaviour. |
| `premium-boundary.mp3` | `Welcome to Wales. You are now entering Monmouthshire.` | Typical names-only boundary announcement. |
| `premium-short-fact.mp3` | `Stroud grew around the wool trade, with steep Cotswold valleys providing fast-flowing water for its historic mills.` | Typical fact duration, consonants and changing speech energy. |

Add a calibration-only manifest containing:

- generation date in ISO-8601 format;
- proxy speech-contract revision;
- ElevenLabs model and output format;
- non-secret voice identifier or an explicit voice-configuration revision;
- exact announcement text;
- byte length and SHA-256 for each file;
- measured raw integrated LUFS and true peak;
- a statement that the files contain no personal data, credentials or custom rider instructions.

Do not store an API key, proxy credential, installation identifier or authenticated request headers in the manifest, project or build log.

Fixture generation is a manual maintenance action, not app runtime behaviour. Regenerate the set only when the configured voice, model or material speech character changes. Changing the processing profile alone must not regenerate the fixtures.

## Processing model

Refactor only as far as necessary to give production playback and the calibration lab one reusable Premium Voice processor. A suitable boundary is:

```swift
struct SpeechProcessingProfile: Codable, Equatable, Sendable {
    let outputGainDB: Float
    let compressionPreset: SpeechCompressionPreset
    let presenceGainDB: Float
    let highPassFrequencyHz: Float
    let samplePeakCeilingDBFS: Float
}

protocol PremiumSpeechProcessing {
    func prepare(
        speechAudio: [Data],
        profile: SpeechProcessingProfile
    ) async throws -> PreparedPremiumAudio
}
```

Names are illustrative. Preserve better existing names where they already express the same boundary.

The candidate processing order is:

```text
raw MP3 speech audio
→ decode to PCM
→ high-pass filter
→ broad speech-presence EQ
→ light broadband compression
→ output/makeup gain
→ bounded peak limiting
→ existing production audio-session acquisition
→ playback
→ existing terminal release with notifyOthersOnDeactivation
```

Do not alter announcement generation, proxy authentication, fact generation, retry policy or Google Maps arbitration in this increment.

## Parameter confidence and controls

### Fixed engineering bounds

Start with these as safety bounds rather than user controls:

- High-pass frequency: 100 Hz.
- Compressor attack: approximately 10 ms.
- Compressor release: approximately 120 ms.
- Soft-knee compression.
- Final sample-peak ceiling: −2 dBFS.
- No system-volume manipulation.
- No attenuation or processing of audio owned by another app.

If the selected implementation cannot provide a true-peak limiter, describe the −2 dBFS value accurately as a sample-peak ceiling and verify the rendered candidates offline for inter-sample overs. Do not label a sample-peak calculation as dBTP.

### Calibration controls

Expose only the high-impact variables:

- Output gain: 0 to +12 dB in 0.5 dB steps.
- Compression: Off, Light, Medium and Strong.
- Presence gain: 0 to +4 dB in 1 dB steps, centred broadly around 2–3.5 kHz.

Use deterministic preset mappings. Initial mappings may be:

| Preset | Ratio | Threshold |
|---|---:|---:|
| Off | 1:1 | Not applicable |
| Light | 2:1 | −18 dBFS |
| Medium | 3:1 | −22 dBFS |
| Strong | 4:1 | −24 dBFS |

These are starting values for the probe, not accepted production constants. Keep attack, release, knee, high-pass frequency and peak ceiling out of the main calibration UI.

### Human calibration follow-up — 2026-08-03

The first physical-iPhone comparison found that the system output-volume value was only sampled when the screen loaded, +12 dB output gain and the original +4 dB presence range were too subtle for useful discrimination, and Strong compression was not perceptually obvious. Candidate A remained acceptable; Candidate B was only slightly clearer and began to sound distorted.

For the next bounded comparison:

- observe `AVAudioSession.outputVolume` dynamically while the lab is visible;
- expose output gain as 0, +6, +12, +18 and +24 dB choices;
- expose presence gain as 0, +6, +12 and +18 dB choices;
- retain the deterministic compression mappings, visibly state that they apply only to Candidate B, and add automated evidence that Strong changes the rendered Premium fixture;
- add an explicit internal-build-only switch that applies the current Candidate B profile to normal Premium Voice announcements after leaving the lab;
- persist that experimental override locally, update it when Candidate B changes, and make its active state obvious;
- never enable the override merely by pressing Candidate B, saving a profile or opening the lab;
- compile the override and all related keys/UI out of normal Release/TestFlight.

This is a reversible road-evaluation override, not promotion of Candidate B to the production profile. The production default remains unchanged until Rob explicitly selects a final profile after road evidence.

Do not display a value as an exact LUFS target unless the app actually implements a standards-based loudness measurement. It is acceptable for the lab to expose output gain and then measure saved candidates offline. The expected comparison band is roughly −16 to −14 LUFS, beginning around −15 LUFS, but perceptual helmet evidence decides the result.

## Calibration-lab interface

Place the entry under:

```text
Settings → Advanced → Developer → Speech Calibration
```

Show it only when the internal calibration compilation condition is enabled.

The screen must provide:

- stationary-use warning and refusal to operate while a ride session is active;
- current output route;
- current system output-volume snapshot, explicitly read-only;
- fixture selection: Place Name, Boundary and Short Fact;
- provider selection: Premium Fixture or Apple Voice;
- Current A and Candidate B buttons;
- Output Gain, Compression and Presence controls for Candidate B;
- Repeat/stop control;
- Reset Candidate B to the current production profile;
- Save Candidate B locally as a named calibration profile;
- copy/export of the selected profile as non-sensitive JSON;
- visible playback state and terminal success/failure;
- a reminder to start YouTube Music manually before comparison.

The app cannot start, fade or directly control YouTube Music. Each A/B playback must use the existing RideHorizon audio-session policy so iOS interrupts and restores the external app exactly as it does for a normal announcement.

Apple Voice playback must use the same fixture text and the current selected Apple voice, rate, volume and production audio-session lifecycle. Premium Fixture playback must make no network request.

## Build isolation

Use an explicit compilation condition such as:

```text
INTERNAL_AUDIO_CALIBRATION
```

A local Calibration configuration or scheme may enable it. Normal Release/TestFlight must not.

The implementation must prove that the normal Release app bundle contains none of:

- the Speech Calibration navigation entry or view;
- the three MP3 fixtures or their manifest;
- calibration-only labels or saved-profile UI;
- code that can enable the lab through a runtime toggle.

The reusable production processor and the selected production profile remain in Release, because they are normal app functionality.

## Persistence

Calibration profiles may use a dedicated `UserDefaults` key in internal builds. Persist:

- profile name;
- processing parameters;
- fixture/provenance revision;
- saved timestamp.

Do not make a saved experimental profile silently become the production default. Promotion is an explicit source/configuration change after the human gate.

## Diagnostics

Use the existing privacy-safe diagnostic chain. Add only calibration-specific values that are needed to reproduce a comparison:

- fixture identifier, not announcement text;
- provider;
- profile identifier;
- applied gain;
- compression preset;
- presence gain;
- resulting sample peak;
- processing duration;
- playback/session terminal outcome.

Do not log audio bytes, announcement text, coordinates, external-app identity, credentials or file-system paths containing personal information.

## Automated evidence

Add focused tests proving:

1. Every Premium fixture is present and its SHA-256 matches the manifest in a calibration build.
2. The fixture player performs no proxy request.
3. Every play starts from immutable raw bytes; repeating Candidate B does not accumulate processing.
4. Output gain and compressor mappings are deterministic.
5. Every processed buffer remains within the configured sample-peak ceiling.
6. Cancellation during preparation prevents playback.
7. Playback completion, cancellation, preparation failure and audio-session failure all follow the existing terminal release path.
8. Current A uses the production profile and Candidate B uses only the edited candidate profile.
9. Apple Voice uses the production Apple path and does not use Premium fixtures or Premium processing.
10. A saved calibration profile persists without replacing the production default.
11. The lab refuses playback while a ride session is active.
12. A normal Release build omits the calibration entry and resources.

Run the complete existing iOS unit target after focused tests pass. Do not weaken or replace the current audio-interoperability coverage.

## Physical calibration gate

Use the physical iPhone and helmet headset. Configure and record results only while stopped.

For each fixture:

1. Establish Current A with no external audio.
2. Start YouTube Music at the rider's normal listening volume.
3. Compare Current A and Candidate B through the phone output.
4. Repeat through the Bluetooth helmet headset.
5. Try Candidate B at stopped/quiet conditions and with representative recorded road noise or another safe stationary approximation.
6. Record intelligibility, harshness, pumping, clipping, onset loss and the music-restoration transition.
7. Compare live Apple Voice using the same text.

Rate each candidate from 1 to 5 for:

- word intelligibility;
- place-name intelligibility;
- loudness relative to normal music;
- comfort while stopped;
- absence of harshness or pumping;
- acceptability of music restoration.

Stop and reject a profile on audible clipping, painful stopped-condition loudness, strong pumping, lost word onsets, stuck music suppression, route loss, duplicate playback or unsafe distraction.

Rob selects one of:

- accept Current A;
- accept Candidate B;
- revise Candidate B locally and repeat without a rebuild;
- reject the processing approach and hold production unchanged.

## Promotion after calibration

Only after Rob accepts a profile:

1. Record the selected parameters and measured rendered LUFS/true peak in `docs/architecture/plans/AUDIO_INTEROPERABILITY_VALIDATION_PLAN.md`.
2. Promote the selection into the single production `SpeechProcessingProfile` default.
3. Keep experimental saved profiles internal.
4. Run focused processor tests, the complete iOS unit target and signed Debug/Release builds.
5. Install the promoted candidate on the physical iPhone.
6. Repeat `TF-AUDIO-01`, `TF-AUDIO-02` and `TF-AUDIO-05` through the helmet.
7. Stop again before Google Maps tuning, archive or TestFlight upload unless the existing `RH-004` gate is satisfied.

## Non-goals

- A server-side fact or speech-audio cache.
- An on-device general speech-audio cache.
- Predictive boundary prefetch.
- GPX or destination input.
- Customer-visible DSP controls.
- Automatic ambient-noise measurement or microphone use.
- System-volume control.
- Cross-app fade control.
- Google Maps behaviour changes.
- Server transcoding or a new DSP service.
- Automatic regeneration of fixture audio.

## Deterministic verification

Run the physical-device unit target:

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj -scheme RideHorizon -destination 'platform=iOS,id=00008150-000C70883E87401C' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData-SpeechCalibration -only-testing:RideHorizonTests
```

Expected result: `** TEST SUCCEEDED **` with zero failures.

Build the internal calibration candidate:

```bash
xcodebuild build -project /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj -scheme RideHorizonCalibration -destination 'platform=iOS,id=00008150-000C70883E87401C' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData-SpeechCalibration -allowProvisioningUpdates
```

Expected result: `** BUILD SUCCEEDED **`, and the built app exposes Speech Calibration under Developer settings.

Build the normal Release candidate:

```bash
xcodebuild build -project /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj -scheme RideHorizon -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData-SpeechCalibration-Release CODE_SIGNING_ALLOWED=NO
```

Expected result: `** BUILD SUCCEEDED **`, and inspection finds no calibration fixtures, manifest, UI entry or calibration-only strings in the Release app bundle.

If implementation chooses a Calibration configuration on the existing scheme rather than a separate `RideHorizonCalibration` scheme, update the second command to match the accepted project structure and record the exact command and result in `Backlog.md`.

## Implementation evidence — 2026-08-03

- Internal build: `RideHorizonCalibration`, `0.12.3 (20260803.2300)`, signed, installed and launched on physical device `00008150-000C70883E87401C`.
- Calibration physical-device unit target: 185 passed, zero failed or skipped.
- Normal Debug physical-device unit target: 173 passed, zero failed or skipped.
- Offline processed-candidate inspection: FFmpeg EBU R128 true-peak analysis covered all three fixtures at representative (+6 dB output, Light compression, +2 dB presence) and extreme (+12 dB output, Strong compression, +4 dB presence) settings. The six renders measured between −2.7 and −2.1 dBFS true peak; no inter-sample over exceeded the configured −2 dBFS ceiling.
- Normal unsigned Release build: passed.
- Release bundle resource inspection: no calibration fixture, manifest or calibration-named resource.
- Release executable string inspection: no Speech Calibration navigation/UI label, fixture filename, manifest name or internal saved-profile key.
- Proxy contract, Google Maps policy and production processing profile: unchanged.
- Acceptance state: stopped at Rob's stationary human calibration gate; no candidate has been promoted.

### Follow-up evidence — 2026-08-03

- Internal build: `RideHorizonCalibration`, `0.12.3 (20260803.2345)`.
- Calibration physical-device unit target: 189 passed, zero failed or skipped.
- Normal Debug physical-device unit target: 173 passed, zero failed or skipped.
- Live volume: model-level observation test proves updates after the lab has loaded; physical button behaviour remains part of Rob's UI gate.
- Control wiring: automated fixture comparison proves Strong compression changes rendered samples.
- Override isolation: tests prove Candidate B playback does not activate normal-announcement processing, explicit enablement does, edits update the active profile, disablement restores Current A, and the normal Premium Voice preparer reads the active internal profile.
- Offline processed-candidate inspection: all three fixtures were rendered at representative (+12 dB output, Light compression, +6 dB presence) and maximum (+24 dB output, Strong compression, +18 dB presence) settings. FFmpeg EBU R128 true-peak analysis measured −2.9 to −2.1 dBFS.
- Normal unsigned Release build: passed after the follow-up.
- Release bundle and executable inspection: no calibration resource, navigation/UI label, profile key or ride-override persistence key.
- Production profile, proxy contract and Google Maps policy: unchanged.
- Acceptance state: stopped before Rob's stationary adjustment and authorised internal-profile road evaluation.

## Independent evaluation

A fresh review context must compare the implementation with this specification and the pre-existing audio diff. It must check:

- the delta audit is accurate;
- one processor boundary serves production and calibration without duplicating audio-session policy;
- every processing and playback path remains cancellable and releases audio ownership;
- Release exclusion is proven rather than assumed;
- no fixture-generation credential or request metadata entered Git;
- the lab cannot operate during an active ride;
- automated loudness or peak labels describe what is actually measured.

Rob is the sole acceptance authority for helmet intelligibility, stopped-condition comfort and the perceived transition back to music.

## Paste-ready implementation instruction

```text
Implement SPEECH_INTELLIGIBILITY_CALIBRATION_SPEC.md as a bounded RH-004 calibration probe. Follow AGENTS.md, Backlog.md and docs/architecture/plans/AUDIO_INTEROPERABILITY_VALIDATION_PLAN.md. First audit the existing Premium Voice peak normalisation and audio-engine work and record the delta; do not recreate working components. Generate and bundle the three fixed Premium Voice fixtures through the existing authenticated Fly proxy, with no caching dependency. Add the internal-only Speech Calibration Lab, shared reusable processing boundary, focused tests and Release-exclusion proof. Build and install it on the physical iPhone, then stop at the human calibration gate. Do not promote a new production profile, tune Google Maps, change the proxy contract, archive or upload to TestFlight until Rob selects a candidate.
```

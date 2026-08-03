# RideHorizon Audio Interoperability Validation Plan

Date: 2026-08-03

Status: **Candidate `0.12.3 (20260803.2218)` is installed at the physical YouTube Music validation gate. Music interruption works consistently from both Test Mode controls; the revision removes the artificial primary-audio wait from every build mode, applies bounded per-announcement Premium Voice gain and extends correlated latency diagnostics. All 172 physical-device unit tests and signed Debug/Release builds pass. Do not tune Google Maps behaviour until Rob accepts the revised YouTube Music result.**

## Authority and scope

This document is the requirements and validation plan for RideHorizon coexistence with audio from other iOS apps.

- `Backlog.md` remains the authority for delivery status and gates.
- `docs/operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md` remains the authority for test runs and results.
- This document owns the audio-interoperability requirements, platform assumptions, diagnostic contract and staged test design.
- `docs/architecture/specs/SPEECH_INTELLIGIBILITY_CALIBRATION_SPEC.md` owns the bounded intelligibility probe: audit the existing peak-normalisation delta, use three immutable Premium Voice fixtures, keep the calibration lab internal-only and stop for human profile selection before changing the production default.

The current commitment is a private TestFlight beta. This is a production-quality and implementation-fidelity increment, not new product breadth.

## Outcome

RideHorizon should speak intelligibly alongside music and navigation without leaving other audio suppressed, causing a sudden restoration in perceived volume, talking over an observable navigation prompt, or losing a pending RideHorizon announcement.

The work proceeds one interaction at a time:

1. Make the observable event chain and diagnostic export sufficient.
2. Verify and correct YouTube Music coexistence.
3. Hold a review gate.
4. Verify and correct Google Maps coexistence.
5. Consider other music and navigation apps only after the first two behaviours are understood.

## Product requirements

### Common requirements

- RideHorizon owns an active playback audio session only while it is playing its own synthesised speech audio.
- It deactivates that session promptly after completion, cancellation, failure or ride end, using `notifyOthersOnDeactivation`.
- A pending announcement is not silently lost because another app is producing audio.
- If RideHorizon stops an announcement because iOS reports competing primary audio or an interruption, it retains one restartable pending announcement and prevents duplicate or stale playback.
- Restarted speech begins from the start of the announcement. Resume within the encoded audio is not required.
- A superseded announcement must not restart after the rider has moved to a newer context or ended the ride.
- RideHorizon must never change the iPhone system volume.
- The behaviour must work for both Apple Voice and Premium Voice unless a provider-specific limitation is recorded.
- Audio policy and diagnostics must continue when RideHorizon is backgrounded during an explicitly active ride, subject to the events iOS exposes.

### Music behaviour

When YouTube Music is already playing:

- RideHorizon must not delay or block an announcement merely because `secondaryAudioShouldBeSilencedHint` is true before playback.
- Fact generation, announcement-text preparation and speech-audio generation must progress normally while music is present.
- When RideHorizon plays, it should temporarily interrupt music so the announcement remains intelligible. RideHorizon must promptly deactivate its session with `notifyOthersOnDeactivation` so iOS can resume the interrupted app.
- Music should return smoothly to its previous perceived level within one second after RideHorizon releases its session.
- There must be no persistent suppression, abrupt volume blast, duplicate announcement or late stale announcement.

When YouTube Music starts during RideHorizon speech, record the actual iOS event sequence before selecting any further policy. The provisional preference is that music remains interrupted until the short announcement ends. If iOS instead interrupts RideHorizon, RideHorizon should recover once without duplication when the OS permits.

### Navigation behaviour

When RideHorizon has observed a genuine interruption or secondary-audio begin notification before an announcement becomes ready:

- RideHorizon waits for every corresponding end or resumable event, then starts the pending announcement immediately. Overlapping observed intervals must all end before restart. There is no timer-based settling delay.
- A preflight `secondaryAudioShouldBeSilencedHint` value alone never starts a wait because it is also present during ordinary YouTube Music playback and does not identify navigation.

When Google Maps begins speaking during a RideHorizon announcement and iOS exposes the event:

- RideHorizon stops promptly.
- It retains the current announcement as pending.
- After iOS reports that playback may resume, or reports the end of the primary-audio interval, RideHorizon restarts the announcement once from the beginning.

If Google Maps overlaps without an event available to RideHorizon, record that as a platform-observability finding. Do not claim that app identity or spoken-content classification can be inferred when iOS did not expose it.

## iOS platform model and assumptions

### Known platform facts

- Each app declares its own `AVAudioSession` category, mode and options.
- iOS arbitrates the combination when an app activates or changes its audio session.
- RideHorizon can inspect its own session configuration and observe coarse state such as `isOtherAudioPlaying`, `secondaryAudioShouldBeSilencedHint`, interruption notifications, secondary-audio hint notifications, route changes and media-services resets.
- RideHorizon cannot inspect another app's bundle identifier, category, mode, options, content type or spoken text through the public `AVAudioSession` API.
- `secondaryAudioShouldBeSilencedHint` means another non-mixable primary audio session is active and that optional secondary audio in the receiving app may yield. It does not mean “navigation audio”.
- Secondary-audio hint notifications are not a reliable background app-identification mechanism. Their delivery constraints and the absence of an app identity must be treated as part of the test evidence.

### Increment 1 RideHorizon configuration

At the start of this plan, RideHorizon configures its playback session as:

- category: `.playback`;
- mode: `.spokenAudio`;
- options when music interruption is enabled: no mixing or ducking category option, so activating the session interrupts other audio;
- options when music interruption is disabled: `.mixWithOthers`;
- activation immediately before speech playback;
- deactivation with `.notifyOthersOnDeactivation` after playback.

The implementation does not request `.interruptSpokenAudioAndMixWithOthers`. Do not add it during Increment 1: it mixes ordinary music while specially interrupting spoken-audio sessions, which does not implement the accepted YouTube Music pause/resume policy and would prematurely tune navigation behaviour.

Apple controls the attenuation applied by `.duckOthers`; RideHorizon cannot select a ducking amount. The accepted 2026-08-03 decision is therefore to use temporary interruption for the YouTube Music increment. See `docs/adr/0001-interrupt-media-during-announcements.md`.

### Test hypotheses, not facts

- YouTube Music is likely to behave as persistent media playback. The physical validation must establish whether it pauses when RideHorizon activates its non-mixing session and resumes smoothly after RideHorizon deactivates with notification.
- The target phone has already shown `secondaryAudioShouldBeSilencedHint == true` while YouTube Music was playing. This explains the earlier indefinite deferral but does not identify YouTube Music or classify it as spoken audio.
- Google Maps is likely to use intermittent audio-session activation for navigation prompts, but its exact category, mode, options and timing are private implementation details and may change by app or iOS version.
- Google Maps may interrupt RideHorizon, generate a primary-audio hint, mix, duck or overlap. Only physical evidence on the target configuration decides which path we support.

## Diagnostic requirements

The private-beta diagnostic ring buffer is the baseline. Keep its current bounds of 2,000 events, seven days or 1 MiB, its file protection, backup exclusion, local export and clear controls during the private beta.

Diagnostics have three distinct levels:

- the private-beta timing chain is enabled in beta builds so a road-test export can explain latency and audio lifecycle without Xcode;
- verbose proxy HTTP and DNS logging remains Debug-only and explicitly switched off by default;
- a public-production build must default diagnostics off and provide a build-time compilation switch that can remove the persistent recorder and diagnostic UI from the binary. Re-enable it only in a deliberate diagnostic build when investigating reported latency.

The app makes two independent proxy calls for fact-backed Premium Voice announcements: `/v1/fact` returns text after the proxy calls OpenAI, then `/v1/speech` returns MP3 audio after the proxy calls ElevenLabs. Names Only and other non-fact modes skip `/v1/fact`; Apple Voice skips `/v1/speech`. Client timestamps must therefore distinguish place detection, reverse geocoding, fact request/response, speech request/last-byte response, local decode/preparation, audio-session activation and playback start.

For beta network evidence, snapshot the public Network-framework path classification at the start and result stage of fact generation and Premium Voice TTS: satisfied state, interface class, expensive and constrained flags, plus the coarse link-quality category on iOS 26 or later when available. Do not duplicate network metadata onto unrelated ride events. Do not record carrier identity, SIM/service identifiers, IP addresses or radio details. iOS does not expose cellular dBm or signal bars through a supported public API, and the coarse link-quality value must supplement measured request duration rather than gate requests.

The current client chain measures aggregate stage duration, including any retry and backoff, but does not persist individual attempt counts or failure classes. Debug-only proxy logs and optional server diagnostics provide that deeper evidence during an investigation. Add persistent per-attempt events only if beta failures show that aggregate timing and terminal outcome are insufficient.

Before behavioural tuning, confirm that one exported log can reconstruct the following sequence without console access:

`fact generation → announcement text ready → queued → speech-audio request → speech audio ready → audio-session activation → playback → interruption or completion → audio-session release → requeue/restart decision`

Each relevant entry should contain, where applicable:

- ISO-8601 timestamp;
- a stable diagnostic or ride-session identifier;
- monotonic sequence number or elapsed time so clock changes cannot reorder events;
- announcement correlation identifier, without announcement text;
- event type and decision reason;
- ride state and foreground/background state;
- selected speech provider and playback path;
- RideHorizon audio category, mode and options;
- audio-session activation/deactivation result;
- `isOtherAudioPlaying`;
- `secondaryAudioShouldBeSilencedHint`;
- interruption begin/end, documented reason and `shouldResume` when supplied;
- secondary-audio hint begin/end;
- output route and route-change reason;
- output-volume snapshot, clearly treated as system output volume rather than measured loudness;
- cancellation, supersession, terminal outcome and restart outcome.

Do not log:

- generated facts or announcement text;
- speech audio or external audio;
- precise coordinates or route history;
- API keys, tokens or credentials;
- an inferred external-app identity.
- carrier identity, SIM/service identifiers, IP addresses or precise radio measurements.

The test operator records the known external app and scenario in `docs/operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md`. The app log records only what iOS and RideHorizon actually observed.

## Increment 1 — Diagnostic sufficiency and YouTube Music

### Outcome

An exported diagnostic log explains every state transition in a YouTube Music test, and YouTube Music pauses and resumes safely around one RideHorizon announcement.

### Included

- Audit the current diagnostic schema against this plan.
- Add only the missing correlation, pipeline, decision and interruption fields needed to reconstruct the event chain.
- Add or update unit tests for ordering, correlation, cancellation, immediate preflight behaviour, event-driven interruption recovery, session activation and release.
- Route every manual Test Mode advance through one announcement/audio interface so the main sheet and log view cannot select different audio behaviour.
- For this development campaign, default Test Mode on in Debug builds through one explicit configuration/migration point. Keep Release/TestFlight default off and preserve subsequent explicit choices.
- Run stationary physical tests with YouTube Music, first through the phone output and then through the helmet Bluetooth headset.
- Correct the smallest confirmed policy or lifecycle defect.

### Non-goals

- Google Maps tuning.
- Identifying YouTube Music programmatically.
- Recording or analysing external audio.
- General settings redesign.
- Changing the proxy, ElevenLabs service or fact-generation policy unless evidence isolates a related defect.

### Stationary scenarios

Use one announcement per scenario and export diagnostics after each run:

1. No external audio: establish baseline activation, playback and release.
2. YouTube Music already playing: trigger Apple Voice and verify pause/resume.
3. YouTube Music already playing: trigger Premium Voice and verify pause/resume.
4. Start YouTube Music while RideHorizon is speaking.
5. Stop or pause YouTube Music immediately before triggering a RideHorizon announcement.
6. End ride during waiting, speech-audio generation and active playback; verify no later speech occurs.
7. Repeat the passing coexistence case through the helmet Bluetooth headset.

For each scenario record app/build version, iOS version, output route, RideHorizon music-interruption setting, speech provider, UTC start/end, subjective speech intelligibility, perceived music restoration and the exported diagnostic path.

### Acceptance evidence

- Automated tests prove that preflight audio hints add no delay, genuine interruption end events restart once without a timer, stale announcements do not restart, diagnostic ordering remains correlated and every terminal path releases the session.
- The complete iOS unit target passes.
- The signed app builds, installs and launches on the physical iPhone.
- YouTube Music remains usable, pauses during RideHorizon speech and returns smoothly within one second after release.
- Premium Voice generation proceeds while music is present and exposes a diagnosable request state; it does not silently stall.
- Exported diagnostics explain the observed outcome without relying on Xcode's live console.
- No external app identity, content, coordinates or credentials appear in the export.

### Physical gate evidence and Increment 1 revision — 2026-08-03

Rob confirmed that YouTube Music now pauses for announcements triggered from both the main sheet and the log view. The shared trigger path therefore passes; the earlier inconsistent pause/duck behaviour is not present in build `0.12.3 (20260803.2100)`.

The same run exposed three revision items:

- YouTube Music resumes abruptly and Premium Voice is perceptually quieter than the resumed music.
- The latest five successful Premium Voice samples took five to six seconds from `announcementTextReady` to `audioPlaybackStarted`.
- Test Mode should start this campaign with Road enabled and Names Only selected, without changing the Release/TestFlight live-riding defaults.

The exported phone diagnostics isolate the measured five-to-six-second interval as:

- three to four seconds in the bounded primary-audio wait;
- one to two seconds from `ttsRequested` to `speechAudioReady`;
- zero to one second from speech-audio readiness to playback, including audio-session activation and timestamp rounding.

Decision superseded on 2026-08-03: remove the three-second primary-audio timer in every mode. A preflight `secondaryAudioShouldBeSilencedHint` does not defer an announcement. Genuine interruption and secondary-audio begin notifications may pause active speech, but recovery is driven only by the corresponding resumable/end event and happens immediately. Test Mode, live mode, Debug and Release/TestFlight use the same rule.

Set Apple utterances explicitly to the maximum supported per-player volume. Do not change system volume. ElevenLabs voice settings do not provide a loudness control: `use_speaker_boost` changes voice similarity and may add latency.

A live 2026-08-03 sample from the configured proxy and voice took 1,058 ms end to end at the proxy boundary. It measured −24.1 LUFS integrated with a −8.2 dBFS true peak, confirming that the source is quiet and has about 6 dB of usable headroom. Premium Voice playback should therefore decode locally and apply per-utterance peak normalisation: no attenuation, at most 2×/+6.02 dB gain, and a target sample peak of −2 dBFS. The decode and peak scan run off the main actor, all chunks in one utterance use the same gain, and audio-engine configuration changes terminate through the normal release/fallback path. This is bounded source-level gain, not system-volume control. Defer compression or server transcoding unless physical evidence shows that conservative peak normalisation is insufficient.

iOS, not RideHorizon, controls how an interrupted third-party app resumes after `notifyOthersOnDeactivation`; there is no public cross-app fade control. Do not simulate a fade by holding the audio session after speech, because that only delays restoration and can leave music suppressed. The next physical gate must judge whether the normalised speech level makes the transition acceptable.

Client diagnostics remain the source for end-to-end perceived latency. Place lookup start, finish, cancellation and phrase-ready events now retain one lookup identifier, so rapid Test Mode advances remain measurable without accidentally joining different requests. Server logs contain total fact-request timing, and optional upstream OpenAI and ElevenLabs timings when `RIDEHORIZON_DIAGNOSTICS_ENABLED=true`; they are supporting evidence, not a replacement for client timing.

The Debug campaign applies Road plus Names Only once per `LocationManager` lifetime. Turning Test Mode off and on does not overwrite a subsequent explicit choice.

### Stop condition and gate

Stop before Google Maps work if music remains suppressed, returns with an unsafe perceived jump, blocks announcements indefinitely, causes duplicate/stale playback, or cannot be diagnosed from the export.

At the gate choose **continue**, **revise**, **refactor**, **research**, **prototype**, **reduce scope**, **pause** or **stop**. Continue to Increment 2 only after Rob confirms the stationary YouTube Music behaviour is acceptable.

## Increment 2 — Google Maps

### Outcome

RideHorizon and Google Maps avoid overlapping speech whenever iOS exposes an actionable event, and interrupted RideHorizon speech is recovered safely and at most once.

### Initial scenarios

1. Google Maps prompt starts and ends before RideHorizon requests speech.
2. RideHorizon becomes ready while a Google Maps prompt is active.
3. Google Maps begins while RideHorizon is speaking.
4. Google Maps issues consecutive prompts during one pending RideHorizon announcement.
5. Repeat through the helmet Bluetooth headset with YouTube Music also playing.

Detailed implementation choices remain deliberately unshaped until Increment 1 evidence and the first Google Maps baseline log are available.

### Acceptance boundary

- Observable Google Maps audio causes the required wait, stop or single restart behaviour.
- No pending announcement is duplicated or replayed after it becomes stale.
- Music restoration remains correct when music is also present.
- Overlap without a corresponding iOS event is recorded as residual platform evidence, not disguised as a solved condition.

## Later applications

After the Google Maps gate, select other apps by actual tester use. Likely candidates are Apple Maps, Calimoto and one additional music or podcast app. Do not assume that evidence from Google Maps generalises to every navigation app.

## Verification commands

Run the complete unit target at each increment checkpoint:

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj -scheme RideHorizon -destination 'platform=iOS,id=00008150-000C70883E87401C' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData-AudioInterop -only-testing:RideHorizonTests
```

Expected result: `** TEST SUCCEEDED **` with zero failures.

Build the signed physical-device candidate:

```bash
xcodebuild build -project /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj -scheme RideHorizon -destination 'platform=iOS,id=00008150-000C70883E87401C' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData-AudioInterop -allowProvisioningUpdates
```

Expected result: `** BUILD SUCCEEDED **`.

## Independent evaluation

A fresh review context should check that every audio-session acquisition has a bounded release, every restart is correlated with a still-current announcement, and diagnostic fields cannot carry prohibited content. Rob provides the perceptual judgement for interruption, restoration, intelligibility and distraction on the physical phone and headset.

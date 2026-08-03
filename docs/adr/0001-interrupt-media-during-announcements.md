# ADR 0001: Interrupt media during announcements

Status: Accepted

Date: 2026-08-03

## Context and decision driver

RideHorizon announcements were not consistently intelligible over YouTube Music. iOS controls the attenuation produced by `AVAudioSession.CategoryOptions.duckOthers`; the app cannot tune the ducking amount. Rob observed both insufficient attenuation and inconsistent apparent pause/duck behaviour while using two UI triggers that already call the same location-advance method.

The immediate commitment is a safe private iPhone beta. Increment 1 of `AUDIO_INTEROPERABILITY_VALIDATION_PLAN.md` covers YouTube Music only; Google Maps policy remains behind a later evidence gate.

## Decision

While the existing **Interrupt music while speaking** setting is enabled, RideHorizon will activate a non-mixing `.playback` / `.spokenAudio` session only when its own speech playback starts. This temporarily interrupts other audio instead of requesting system-controlled ducking. RideHorizon will deactivate promptly after every terminal playback path using `.notifyOthersOnDeactivation`, allowing the interrupted app to resume when iOS permits.

When the setting is disabled, RideHorizon will continue to use `.mixWithOthers`.

Do not add `.interruptSpokenAudioAndMixWithOthers` in this increment. It implements a different policy—mix ordinary audio while specially interrupting spoken-audio sessions—and would pre-empt the Google Maps validation gate.

## Alternatives considered

- Keep `.duckOthers`: rejected for Increment 1 because its system-controlled attenuation was insufficient in the target scenario and RideHorizon cannot tune the amount.
- Change system or application volume: rejected because public iOS audio-session policy does not provide an appropriate per-app ducking-level control, and RideHorizon must never change system volume.
- Use `.interruptSpokenAudioAndMixWithOthers`: deferred because it would shape navigation interoperability before Google Maps evidence exists.

## Consequences

- YouTube Music should pause rather than remain quietly mixed during an announcement.
- Smooth restoration depends on correct, prompt session deactivation and the interrupted application's response to iOS notification; physical evidence remains mandatory.
- Other audio applications may also be interrupted while RideHorizon speaks. Google Maps behaviour remains unclaimed until Increment 2.
- The audio-session policy becomes an explicit typed value in code and diagnostics rather than a Boolean named after ducking.

## Validation and reversal triggers

Validate with Apple Voice and Premium Voice through the phone output and the helmet Bluetooth route. Revisit this decision if music fails to resume within one second, resumes with an unsafe perceived jump, speech remains unintelligible, or Increment 2 shows unacceptable navigation consequences.

## Traceability

- Work item: `Backlog.md` RH-004, Increment 1
- Validation plan: `AUDIO_INTEROPERABILITY_VALIDATION_PLAN.md`
- Evidence record: `TESTFLIGHT_FIELD_TEST_EVIDENCE.md`
- Apple references: [duckOthers](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/duckothers), [mixWithOthers](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers), [notifyOthersOnDeactivation](https://developer.apple.com/documentation/avfaudio/avaudiosession/setactiveoptions/notifyothersondeactivation)

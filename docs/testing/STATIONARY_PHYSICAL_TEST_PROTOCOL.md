# RideHorizon Stationary Physical-Test Protocol

Date: 2026-08-05
Status: Active for the exact Internal TestFlight build.

## Purpose

Run the candidate-specific physical checks while safely stopped, in two deliberately separate layers:

1. the iPhone app on its own; and
2. the same RideHorizon behaviour through the paired X-COM2 helmet headset.

This protocol owns the method and layer separation. [`../operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md`](../operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md) remains the sole run record, status matrix and release evidence. [`../operations/testflight/RIDE_UAT_PROTOCOL.md`](../operations/testflight/RIDE_UAT_PROTOCOL.md) owns moving-road UAT only.

## Authority and boundaries

| Concern | Owner document | Boundary |
| --- | --- | --- |
| Paired iPhone, X-COM2 voice paths, source volumes and `Ride feedback` Shortcut | [`../operations/headsets/XCOM2_IPHONE_SETUP_AND_STATIONARY_TEST.md`](../operations/headsets/XCOM2_IPHONE_SETUP_AND_STATIONARY_TEST.md) | One-time setup prerequisite. It does not test RideHorizon. |
| Exact-build stationary product test method | This protocol | Phone-only and X-COM2 execution cards, including how to record each result. |
| Test result, build identity, evidence and findings | [`../operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md`](../operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md) | The only status/checklist record. |
| Moving location, ordinary navigation foreground use, ride attention, real mobile network, power and heat | [`../operations/testflight/RIDE_UAT_PROTOCOL.md`](../operations/testflight/RIDE_UAT_PROTOCOL.md) | Requires a moving motorbike; never reproduce it in this protocol. |

Do not create a second pass/fail checklist here. Each execution card below names its existing `TF-*` result row.

## Preconditions

1. Complete the X-COM2 setup guide once. Record only the configuration result and any locked-phone limitation; do not record it as RideHorizon evidence.
2. Install the exact Internal TestFlight build. Start a run record before opening RideHorizon.
3. Park safely. Do not run this procedure while riding, at a roadside stop that needs attention, or while another installation is in progress.
4. Record the iPhone/iOS, X-COM2 connection, music source, navigation app, starting conditions and exact build in the field-evidence record.
5. Preserve the first diagnostic export after a failure before restarting, reinstalling, changing settings or troubleshooting.

## Layer 1 — phone-only app checks

Disconnect the X-COM2 or route output to the iPhone. This isolates app lifecycle, permission, UI and diagnostic behaviour from Bluetooth and headset variables.

| Existing evidence row | Execute while stopped | A pass requires |
| --- | --- | --- |
| `TF-INSTALL-01` | Clean install/onboarding, consent and privacy link. | Exact build, no credential prompt, Test Mode off and retained screen evidence. |
| `TF-SESSION-01` to `TF-SESSION-03` | Open idle; Start ride; End ride. | Clear state transition plus diagnostic/location-indicator evidence that continuous work and audio ownership are bounded. |
| `TF-AUDIO-01` (phone portion) | Preview Apple Voice and Premium Voice with no other audio. | Each provider reaches the iPhone once and finishes cleanly. This establishes the app/provider path only; the result is not a Pass until the helmet portion below also passes. |
| `TF-PROXY-01` | Exercise Premium Voice after the defined idle period. | One bounded Premium Voice result or one bounded Apple Voice fallback; no late duplicate speech. |
| `TF-IDLE-01` to `TF-IDLE-05` | Run the inactivity/continue/end cases and, where required, use the built-in test route only while parked. | The stated alert/notification, timeout, movement-recovery and GPS-accuracy outcomes in the evidence matrix. |
| `TF-END-01` and `TF-END-02` | End Ride, lock the phone and leave it; then reopen after manual or automatic end. | No later location/network/speech/audio event, and an idle-only reopen state. |

Phone-only evidence does **not** prove speech intelligibility, Bluetooth route handling, source-volume adequacy or coexistence with other audio. Those belong to Layer 2.

## Layer 2 — X-COM2 helmet checks

Reconnect the X-COM2. Confirm the headset is connected and its configured source volumes are usable, using the setup guide only as a prerequisite. Record the actual RideHorizon result below, not a repeat of the setup result.

| Existing evidence row | Execute while stopped | A pass requires |
| --- | --- | --- |
| `TF-AUDIO-01` | Preview Apple Voice and Premium Voice, one at a time, with no other audio. | Each provider plays once through X-COM2, is intelligible at the normal configured source level, ends cleanly and leaves no active RideHorizon audio session. |
| `TF-AUDIO-02` | Start normal music. Trigger one Apple Voice and one Premium Voice announcement using only parked controls. | Music is interrupted only for each announcement, both voices are intelligible, music returns smoothly within the stated limit, and there is no sudden loud return, duplicate or stuck suppression. |
| `TF-AUDIO-06` | During an active ride session while parked, disconnect and reconnect the X-COM2 once. | The audio route change is handled without a blast, stuck interruption, duplicate speech or retained long-lived audio ownership. |

### Parked navigation coexistence observation

Start the usual navigation app only while parked. If it naturally produces a prompt during a parked RideHorizon announcement, retain a diagnostic observation of whether RideHorizon paused/deferred/restarted safely. This is supporting evidence for `TF-AUDIO-04`; it cannot mark that moving-road test as Pass. If no prompt occurs, record **Not observed**, not Pass.

The moving road UAT remains the only evidence that navigation and music coexist acceptably during ordinary riding demand.

## Screen-lock and background handling

Screen lock is an app lifecycle test, not a headset setup test.

- Run the stationary inactivity/end-of-ride cards in Layer 1. They establish that bounded background work, notification/alert handling and cleanup work while the phone is locked.
- `TF-LOC-02` and `TF-LOC-03` remain moving-road tests because the meaningful claim is continuity during real movement with the screen locked or navigation foregrounded.
- Do not claim that a parked lock-screen pass proves live moving-background location accuracy.

## Stopped feedback capture

Capture feedback only after the relevant phone-only or helmet check has finished and the tester is stopped.

1. First use the configured **Ride feedback** Siri Shortcut through X-COM2, if it works in the current lock state.
2. If it fails, use ChatGPT Dictation with touchscreen gloves; remove a glove if necessary.
3. If ChatGPT Dictation is unavailable, use iOS keyboard Dictation in the message field.
4. Record the method actually used and whether the phone was locked. Preserve only the concise observation and supporting diagnostic/export reference in the field-evidence record; do not commit the raw note or unrelated personal data.

The feedback method is test-operability evidence. It is not a RideHorizon product pass/fail and it must never require interaction while moving.

## Exit and hand-off

The stationary gate is complete only when the required exact-build result rows in the field-evidence record pass. A failure in lifecycle, privacy, music restoration, audio route or provider behaviour blocks moving UAT unless the product scope is safely reduced and the release gate is re-evaluated.

After the stationary gate, hand only the moving-only risks to the road UAT: real location continuity, screen-lock/navigation foreground while moving, ordinary audio attention, natural network degradation, power and heat.

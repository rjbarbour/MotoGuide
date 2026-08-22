# RideHorizon Owner Ride UAT Protocol

Date: 2026-08-05

Protocol revision: 3

Status: Active method for the exact Internal TestFlight build selected in [`TESTFLIGHT_FIELD_TEST_EVIDENCE.md`](TESTFLIGHT_FIELD_TEST_EVIDENCE.md). The protocol deliberately does not embed a release-candidate number.

Evidence record: [`TESTFLIGHT_FIELD_TEST_EVIDENCE.md`](TESTFLIGHT_FIELD_TEST_EVIDENCE.md)

Finding format: [SEERS — Standardised Bug Reporting](https://app.notion.com/p/322a4c502b1781e9873cd3008281d9f6), reviewed on 2026-08-05.

## Purpose

Test only what needs a moving motorbike: real movement and mobile data, a helmet headset, music, ordinary navigation in the foreground, rider attention, and real-world power and heat.

This is a technical owner-acceptance run. It is not a systematic comparison of content modes or fact quality. Those can be tested safely while stationary with simulated or recorded routes.

## Current owner-use scenario

Before departure, confirm that RideHorizon Settings shows the exact version/build selected in the evidence record. Stop if it does not match. Then use one configuration for the whole ride:

- the confirmed exact Internal TestFlight build;
- Test Mode off;
- Short Facts and Premium Voice;
- street off; town, county, region and country on;
- normal helmet headset, music and navigation volumes;
- the usual navigation app remains foregrounded;
- the phone uses its normal mounted and power arrangement, recorded before departure.

Do not change settings, inspect logs, use ChatGPT or handle the phone while moving.

## Conversation design

The UAT chat is the operator interface. Assume limited cognitive bandwidth.

Before departure, the assistant asks **one short question per message**. It establishes only:

1. the installed version and build;
2. the RideHorizon settings;
3. the headset, music app and navigation app;
4. the phone position, charging arrangement and starting battery percentage;
5. whether the rider is parked and ready.

The assistant then gives the single ride card below and waits. It must not add a second checklist.

After the ride, the assistant again asks **one question per message**. It starts with safety and distraction, then announcement continuity, audio behaviour, power and heat, and finally the diagnostic export. It asks only what the rider can reasonably remember or inspect while parked.

## Ride card

> **Ride normally. Do not interact with the phone while moving.**
>
> Notice only:
>
> - did RideHorizon speak at plausible place changes, without stale or repeated speech;
> - could you understand it first time;
> - did music stop and return smoothly;
> - did navigation remain clear;
> - was anything distracting or unsafe?
>
> When safely parked: end the ride, note the battery and whether the phone feels normal, warm or hot, then export RideHorizon diagnostics.

## Suggested locality loop

The route is a safe-road suggestion, not a prescribed track. Let the navigation app choose roads and reject any segment that is busy, awkward or unfamiliar.

Suggested waypoint order:

1. begin while safely parked in the Surbiton/Kingston area;
2. Claygate;
3. Esher;
4. Hersham;
5. Weybridge;
6. Molesey;
7. return towards Surbiton/Kingston.

Hampton is an optional extension only if the river crossing and traffic are acceptable on the day. It is not required for this run.

This loop samples several nearby place labels without requiring exact boundary chasing. Record the displayed or announced names after the ride. Do not fail the road test merely because Apple uses an unexpected locality or administrative label; fail it only if the behaviour is missing, unstable, stale, misleading or distracting. Exact Apple-field and boundary analysis belongs to the separate geographic test corpus.

Do not commit an exact route, coordinates or personal location history. Broad areas and observed place-name sequences are sufficient.

## Tests within the single ride

### RUAT3-01 — Moving continuity with navigation foregrounded

Observe whether RideHorizon continues to detect movement and produce appropriately ordered announcements while the navigation app is foregrounded.

Pass when the ride remains active and any announcements heard are plausible for the current or very recent area, without missing core operation, obsolete speech, duplicates or crashes.

Use **Not observed** for a particular locality if no announcement was expected under the selected policy.

### RUAT3-02 — Helmet audio, music and navigation coexistence

Use music and navigation normally. Do not manufacture an overlap while moving.

Pass when RideHorizon is intelligible, music interruption and restoration are smooth, navigation remains usable, and there is no sudden volume increase, stuck suppression or unacceptable distraction.

If navigation overlaps naturally, remember only the outcome. The diagnostic export may show an iOS interruption or primary-audio hint, but iOS does not identify the other app or guarantee an event for every navigation prompt.

### RUAT3-03 — Mobile-network recovery

This is opportunistic. Do not seek poor reception.

Pass when a naturally observed loss or degradation gives bounded silence or one appropriate fallback and later recovers without stale or duplicate speech. Use **Not observed** if reception appears consistently good.

### RUAT3-04 — Power and thermal observation

Power is a meaningful beta risk because GPS, networking, navigation, Bluetooth audio, screen use and wireless charging can combine. It is below immediate distraction and audio-safety risk, but should be observed before broadening the beta.

For this build, record manually while parked:

- start and end battery percentage;
- whether the phone was unplugged, charging or full;
- whether it was mounted, in a pocket or in a top case;
- approximate duration;
- whether the phone felt normal, warm or hot;
- whether behaviour degraded later in the ride.

A charging ride is useful for checking charge trend and heat, but it does not measure RideHorizon battery consumption. A later unplugged run is needed for a battery-drain estimate. The present app does not record battery or thermal state in its diagnostic file.

A later diagnostic increment could record iOS battery percentage and the broad state `unplugged`, `charging` or `full`, plus the system thermal state `nominal`, `fair`, `serious` or `critical`. Public iOS APIs do not provide an exact device temperature or distinguish a Quad Lock wireless charger from a cable, so the rider would still record the physical setup.

## What diagnostics can establish

RideHorizon’s local diagnostic file correlates its own location, geocoding, fact, TTS, playback, ride-state, app-state, network-path and audio-session events by timestamp.

For external audio, it can record:

- broad `isOtherAudioPlaying` and `shouldYieldToPrimaryAudio` snapshots;
- iOS audio-interruption begin/end events and the system’s resume recommendation;
- primary-audio begin/end hints when iOS sends them;
- route changes, output route, output-volume snapshots and media-services resets;
- whether RideHorizon deferred, cancelled, started, finished or restarted an announcement.

It cannot identify Google Maps, YouTube Music or another app by name, inspect their audio, or guarantee a distinct event for every navigation instruction. Apple documents that the primary-audio hint is delivered only to a foreground app with an active audio session, so it is supporting evidence rather than a complete external-audio timeline.

Current interruption behaviour is explicit: RideHorizon stops its active speech, retains the announcement plan and, only when all observed pause sources have ended and the ride is still active, starts that announcement again from the beginning. If iOS ends an interruption without recommending resumption, RideHorizon cancels it. It does not resume from the interrupted word or audio offset.

## Getting diagnostics into the UAT chat

ChatGPT cannot directly read the sandbox of the TestFlight app.

While safely parked:

1. open **RideHorizon → Settings → Advanced → Release diagnostics**;
2. tap **Export diagnostics**;
3. in the iOS share sheet, tap **Copy** and paste the plain JSON text into the UAT chat, or share it directly to an app that accepts plain text.

RideHorizon generates the shared text from the current in-memory diagnostic log, so it includes events that may not yet have reached the app’s delayed local file. The log retains at most seven days, 2,000 events or 1 MiB and excludes coordinates, spoken text and credentials. Copying individual visible event names loses the correlations; sharing the complete JSON text is preferred.

## Post-ride evidence and SEERS handling

For today, record all results and findings only in [`TESTFLIGHT_FIELD_TEST_EVIDENCE.md`](TESTFLIGHT_FIELD_TEST_EVIDENCE.md). Do not create GitHub issues or mutate Backlog.md tasks during the session.

Record each anomaly with:

- **S — Screenshot or evidence:** diagnostic export, screenshot, voice note or direct observation;
- **E — Environment:** build, device/iOS, headset, audio/navigation setup, phone position, power and broad conditions;
- **E — Expected versus actual:** one clear statement of each;
- **R — Reproduction:** what preceded it and an approximate ISO-8601 time where available;
- **S — Severity:** Blocker, Critical, Major, Minor or Trivial.

The assistant distinguishes observation from inference and correlates the diagnostic chain before assigning a technical cause. It records a finding as awaiting triage rather than silently creating a delivery item.

## Deferred road scenarios

Keep these in the road-UAT protocol backlog, not the project delivery backlog, until the owner-use run is complete:

- an active ride with the phone locked for an extended period;
- phone in a pocket with the screen locked;
- phone in a top case with the screen locked;
- Quad Lock wireless charging versus unplugged battery/thermal comparison;
- longer endurance ride;
- deliberate Bluetooth disconnect/reconnect while safely stopped;
- other riders, headsets, navigation apps and music apps.

## Stop conditions

End RideHorizon or stop the test when safely able if it causes distraction, masks navigation, produces a sudden loud restoration, repeatedly speaks stale information, becomes unintelligible at otherwise safe audio levels, crashes, or the phone becomes abnormally hot.

After evidence is recorded, choose one decision: **continue**, **revise**, **reduce scope**, **pause** or **stop**.

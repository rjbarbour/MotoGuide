# MotoGuide Roadmap Status

Date: 2026-07-03

Purpose: keep the roadmap and codebase status in sync. This file records what is implemented, what is partial, what is deferred, and what remains before MVP1 field trial.

## Summary

The plans are now aligned with the codebase at a high level:

- MVP1 default interval is `10 s`.
- MVP1 default content mode is Short Facts.
- Street announcements are off by default; town, county, region, and country are on.
- Deterministic UK place/boundary data is deferred until after MVP1 field trial.
- MVP1 build scope stops at Location screen completion plus first-time rider polish.
- First field trial target is 2026-07-03.
- Standard rider-facing speech term is **announcements**. Use **ride-aware announcements** for the planned delay/mute-by-ride-state feature.
- Fact quality review on 2026-07-03 shows isolated facts improved, but ride sequences still repeat regional topics. The next fact-quality step is ride context, topic memory, and sequence evaluation.
- The commercial vision is broader than MVP1: user-controlled guidance from silent mode to adaptive always-on tour guide, with POI discovery, voice questions, rider preferences, and navigation handoff.
- PMF Factory / 100 Tasks review is now captured in `PMF_FACTORY_100_TASKS_REVIEW.md`; use it to keep validation work focused and to avoid premature scale/funding/org tasks.
- Deep-research report is available at `/Users/rob_dev/DocsLocal/motoguide/resources/MotoGuide_market_deep-research-report.md`.
- Current market-validation operating plan is `TWO_WEEK_MARKET_VALIDATION_PLAN.md`.

## Status By Milestone

| Milestone | Status | Implemented in code | Remaining / deferred |
|-----------|--------|---------------------|----------------------|
| M0 Project setup | Complete for MVP1 field-test setup | Repo, Xcode project, scheme, simulator build result recorded, OTA phone install and launch completed on Robert's iPhone | Current simulator unit-test execution needs a clean rerun; ride behavior still needs field validation |
| M1 Prototype hardening | Complete | Address model, announcement extraction, test route fixture, core tests | None for MVP1 |
| M2 Ride-safe announcement rules | Partial | Boundary priority, quiet mode, names-only, Short Facts, Long Facts, single-slot queue, Bluetooth delay, `10 s` interval | Minimum-distance throttling is not implemented; ride-aware delay/hold logic is planned for M7.5; UI simplification continues under M6.5 |
| M3 UK place context layer | Deferred | Reverse geocoding remains the MVP1 source | Offline deterministic place/boundary lookup deferred until after field trial |
| M4 Real-ride audio validation | Not complete | Background location/audio modes and audio session code exist | Must validate on iPhone with Nex Xcom headset and normal navigation app |
| M5 Facts MVP | Partial | Proxy-backed Short Facts and Long Facts, cache, timeout fallback, refined 35-45 word Short Facts and 75-90 word Long Facts prompts, rider context fields, fact-interest categories, custom fact focus, tests | Sequence quality remains weak: add ride context, topic memory, avoid-topics, optional response topics/novelty, home quiet radius, and sequence-specific evaluation; proxy deployment/domain remains operational work |
| M5.5 Speech voice and audio quality | Partial | Apple voice enumeration, preferred voice selection, preview button, speech provider setting, proxy ElevenLabs TTS client path, and Apple fallback exist | Validate installed voices and proxy ElevenLabs route on phone/Nex Xcom; confirm secret/config on proxy |
| M6 Location screen completion | Partial | Location is the home screen; map-first full-screen layout, compact overlay, summary/context line, last spoken phrase, Quiet state, visible location/geocoder states, speed-gated map interaction, manual zoom/reset controls exist | Nearby towns, previous street, stopped-only zoom presets, presentation tests, and final field readability pass |
| M6.5 First-time rider polish | Partial | Onboarding exists; tracking starts after onboarding; Location-first structure exists; top-level settings are separated from Advanced/Developer; location permission strings are rider-facing; rider context settings exist | Settings readability pass for glare/vibration/gloved use, History polish, final rider-language pass, proxy/audio visible recovery states, App Review/privacy notes |
| M7 Custom instructions | Not started | None | Post-field-trial |
| M7.5 Ride-aware announcement timing | Not started | None | Post-field-trial: delay/hold announcements while cornering, braking, accelerating, rapidly changing heading, or otherwise busy; release only latest relevant update when stopped or steady |
| M8 MVP1 field trial | Not started | Plans updated | First ride report targeted for 2026-07-03 |
| M9 Listening, POI discovery, and navigation handoff | Not started | None | MVP2: simple voice replies, nearby POI suggestions, bounded longer descriptions, and handoff to Google Maps / Apple Maps / other chosen nav target without route planning |
| M10 Rider questions | Not started | None | Later: constrained place/POI questions after M9 validates listening and handoff value |
| M11 Post-MVP direction | Not started | None | Decide after field-trial evidence |

## Code Evidence Checked

- `MotoGuide/LocationManager.swift`: `locationCheckInterval = 10`, `contentMode = .shortFacts`, `testMode = false`, onboarding-triggered `beginRideTracking()`, quiet-mode guards, fact fetch fallback, rider context, voice selection, speech-provider selection, last spoken phrase.
- `MotoGuide/BoundaryType.swift`: `natural`, `namesOnly`, `shortFacts`, `longFacts`, and `quiet` modes.
- `MotoGuide/ContentView.swift`: Location-first map screen, compact overlay, summary/context line, last spoken phrase, quiet indicator, manual map controls, Settings and Log sheets, visible location failure states, and moving-state map lock.
- `MotoGuide/ContentView.swift` pending fix: status message visibility, build metadata line in main header, zoom in/out reliability, settings-string consolidation, and motorbike-readable Settings rows.
- `MotoGuide/OnboardingView.swift`: three-page first-run explanation.
- `MotoGuideTests`: tests cover content modes, location defaults, announcement policy, and place facts.

## MVP2 Direction Notes

- Keep MVP1 passive: sparse place announcements, facts, quiet mode, and reliable helmet audio.
- MVP2 can add explicit listening and POI handoff after real-ride value is proven. This is the first controlled step toward the always-on tour-guide vision.
- Example MVP2 flow: MotoGuide says there are nearby places worth visiting; the rider asks for more detail; MotoGuide gives a bounded description; the rider says "navigate to Caernarfon Castle"; MotoGuide hands the selected POI to the chosen navigation app.
- This remains separate from route planning. MotoGuide may choose or describe a destination, but navigation apps own routing.
- Open-ended rider questions are M10, after the simpler POI suggestion and handoff flow is validated.
- Later versions should test adaptive preferences: topic interests, more/less detail, shorter/longer speech, regions, trip style, and whether riders want an always-on guide for parts of a journey.

## Fact Quality Direction Notes

- `fact-quality/FACT_QUALITY_REVIEW_2026-07-03.md` shows the refined prompt direction: Short Facts at 35-45 words and Long Facts at 75-90 words.
- `fact-quality/FACT_SEQUENCE_QUALITY_REVIEW_2026-07-03.md` shows the remaining failure: good isolated facts still become stale when several nearby places repeat the same regional setup.
- Next contract work: optional `rideContext` with previous spoken places, previous topics, avoid topics, desired novelty, and familiarity policy.
- Next app work: keep a small topic memory for the last 3-5 spoken facts and add a home quiet radius after MVP1 field validation.
- Next test work: a sequence fixture that confirms repeated towns avoid repeating Cotswolds/limestone/stone/wool/cloth/mills unless the fact is truly distinctive.

## Ride-Aware Announcement Notes

- Use rider-facing label: **Ride-aware announcements**.
- The product should delay speech while riding conditions look busy and speak only the latest relevant update when stopped or steady.
- Initial signals can be speed, course/heading change, acceleration, braking, and signal confidence. Do not require perfect lean-angle detection before testing the concept.
- Avoid backlog playback. A delayed announcement that becomes stale should be shortened or dropped.

## Known Sync Notes

- `MILESTONES.md` is the forward roadmap.
- `ROADMAP_STATUS.md` is the current implementation-status ledger.
- `MVP_POLISH_PLAN.md` is the quality/spec bar for M6.5.
- `MAP_SITUATIONAL_AWARENESS.md` is the Location screen design spec.
- `PMF_FACTORY_100_TASKS_REVIEW.md` maps MotoGuide to the local PMF Factory and 100 Tasks material.
- `TWO_WEEK_MARKET_VALIDATION_PLAN.md` turns the deep-research report into the current 14-day validation sprint.
- `MILESTONE_*_STATUS.md` files are historical status notes and should be updated when a milestone changes state.

## Next Human-Operable Steps

1. Finish M6 Location screen completion.
   Expected result: nearby towns, previous street, stopped-only zoom presets, presentation tests, and final field readability pass are present.

2. Finish M6.5 first-time rider polish.
   Expected result: a first-time rider can start and understand MotoGuide without using debug settings, with remaining History/proxy/audio recovery polish tracked separately if it does not block the first ride.

3. Improve facts and audio quality.
   Expected result: real-ride Short/Long Facts are useful to an adult touring rider, repeated nearby places do not restate the same regional topics, the selected Apple voice is acceptable, and the optional ElevenLabs proxy path is either validated or left off for field trial.

4. Confirm the OTA-installed build works on Robert's iPhone.
   Expected result: MotoGuide opens, requests/uses location correctly, speaks through the expected audio route, and is ready for field testing.

5. Run the first MVP1 field trial on 2026-07-03.
   Expected result: one ride report records GPS, background behavior, headset audio, fact timing, and Location screen usefulness.

6. Review the field-trial result against `PMF_FACTORY_100_TASKS_REVIEW.md`.
   Expected result: the next work is either another validation loop, focused polish, TestFlight recruitment, or a pause/reposition decision.

7. Start the 14-day market validation sprint.
   Expected result: the landing-page/survey path, rider interviews, community posts, and private-beta recruitment are driven from `TWO_WEEK_MARKET_VALIDATION_PLAN.md`.

8. After the first field ride, decide whether to implement ride-aware announcements before broader testing.
   Expected result: either M7.5 is pulled forward because speech timing felt distracting, or it stays post-MVP1 because the current sparse timing is acceptable.

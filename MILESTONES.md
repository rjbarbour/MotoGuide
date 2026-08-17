# RideHorizon High-Level Plan

Date: 2026-07-03

Product capability ladder refined: 2026-08-04

Product-direction decision: 2026-08-17

On 2026-08-17, product direction returned to the core RideHorizon motorcycle experience. This dated decision supersedes the dated `Immediate Next Steps` sequence at the end of this document; it does not assert current task status or erase retained milestone history and release evidence. Use `backlog task list --plain` for live delivery status and inspect the selected task through the CLI before claiming it.

## 2026-07-17 Identity Migration

The prototype is being cleanly renamed from RideHorizon to RideHorizon before the first App Store Connect build upload. See `docs/product/plans/REBRANDING_PLAN.md` for the binding identity map, acceptance criteria, and deployment constraint. This migration changes the app's bundle identifier, source namespaces, proxy contract names, and current documentation; it does not change the rider-safety product scope.

## Product Goal

Build RideHorizon into the missing geographic-context layer beside normal navigation. Navigation tells a rider where to turn, where they are going and when they will arrive. RideHorizon helps them understand where they are now, what kind of place they are travelling through and why it matters.

The visual location display is the core product, not a fallback for speech. Higher levels add optional interpretation while preserving the usefulness of the lower levels. RideHorizon should scale from display-only geographic awareness, through sparse boundary and place announcements, to a passive tour guide and then an interactive guide that understands spoken follow-up questions and rider preferences. It may describe or help select a destination and hand it to a navigation app, but it does not become the route planner.

RideHorizon maintains a continuously refreshed, best-available location and place estimate during an active ride. It must not claim that it always knows the rider's exact place: GPS and reverse geocoding can be delayed, coarse or unavailable, and later guide behaviour must preserve that uncertainty.

## Product Capability Ladder

Each level is independently useful. A rider can remain at visual awareness or sparse announcements without being forced into the richer guide experience.

| Level | Rider value | Current behaviour | Principal delta | Roadmap home |
| --- | --- | --- | --- | --- |
| **1. Visual geographic awareness** | See the current location and geographic hierarchy without asking a navigation app to explain the surroundings. | Implemented map-first Location screen; live or test coordinates; Apple reverse-geocoded street, town, county, nation/region and country; visible location/place-lookup states; follow/recentre behaviour and manual pan/zoom. | Finish nearby-town and previous-place context; improve hierarchy presentation and uncertainty/freshness cues; implement and validate the planned speed-gated map-interaction policy; later add deterministic administrative and landscape regions where worthwhile. | Milestones 3 and 6. |
| **2. Passive boundary and place awareness** | Hear occasional confirmation that the journey has entered a meaningful place or crossed a meaningful boundary. | Detects changes between successive reverse-geocoded addresses; prioritises country, nation, county, town and street; supports Quiet, Names Only, Short Facts and Long Facts; applies a cooldown and coalesces or supersedes some pending speech. | Add authoritative landscape/cultural regions, boundary hysteresis and stronger deduplication; make timing responsive to riding demand; prevent repetitive neighbouring-place facts; distinguish meaningful transitions from geocoder noise. | Milestones 2, 3, 5 and 7.5; RH-024 and RH-026. |
| **3. Passive contextual tour guide** | Experience the ride as a coherent journey through landscape, history, roads and contemporary places without having to ask questions. | Short or long proxy-generated fact can follow a boundary announcement; rider interests, familiar regions and custom fact focus influence isolated requests. | Add bounded ride memory, topic continuity and contrast; identify landscape transitions, visible priorities, landmarks and other meaningful events; guide ahead when appropriate; select calm delivery windows; use stops for longer material; build narrative arcs and recaps; ground precise claims and prefer silence over filler. | Milestones 5 and 7; RH-024, RH-025, RH-026, RH-027 and RH-028, followed by separately shaped guide increments. |
| **4. Interactive contextual tour guide** | Ask what or why, request more or less detail, refine the guide and act on a worthwhile nearby place. | Settings can change future fact interests and depth, and the rider can replay the last announcement. There is no microphone listening, speech recognition, contextual dialogue or voice-command state. | Add explicit bounded listening; microphone permission and clear listening state; speech recognition and intent handling; references to the current place, last subject and recent ride context; short moving responses and deferred stopped detail; interruption/cancel controls; session and durable preference refinement; POI selection and navigation handoff. | Milestones 9 and 10. |

The stable foundation beneath all four levels is the active ride's location stream, place-resolution state and recent geographic context. The product-level unit of value changes by level: current place at Level 1, meaningful transition at Level 2, well-timed interpretation at Level 3 and a contextually resolved exchange at Level 4.

Reference models:

- `docs/product/reference/HUMAN_MOTORCYCLE_TOUR_GUIDE_REFERENCE.md`
- `docs/product/reference/INTERACTIVE_TOUR_GUIDE_REFERENCE.md`

## Existing Baseline

The current codebase is not a blank slate. It already contains:

- A SwiftUI app with controls for test mode, speak-after-every-geocode, location check interval, repeated address components, and manual logging.
- `LocationManager`, which requests location, reverse-geocodes coordinates, throttles location updates by interval, handles background audio setup, speaks with Apple speech, and can use proxy-backed ElevenLabs speech with Apple fallback.
- `Address` and `AddressFormatter`, which separate address data and spoken text formatting.
- `AnnouncementDecision`, which decides whether to speak, which address components to include, and how repeat preferences behave.
- `TestRouteFixture`, a named Gloucestershire route with 11 fixed coordinates for manual and simulator testing.
- Unit tests for address formatting, announcement decisions, location interval throttling, test mode, and the route fixture.
- `Info.plist` background modes for audio and location.

Treat this as the baseline. Do not re-plan work that is already implemented unless the milestone is about verification, hardening, or changing behaviour.

## Scope

In scope for MVP1:

- iOS app.
- UK motorbike use case.
- Separate geographic-awareness companion alongside normal navigation, with a map-first display and optional audio.
- Live location tracking.
- Reverse-geocoded address announcements as the current source of place context.
- Ride-safe announcement controls.
- Spoken announcements through Bluetooth helmet audio.
- Physical testing on the user's iPhone 17 Pro Max running iOS 26.5.1.
- Helmet audio testing with a Nex Xcom Bluetooth headset based on Sena technology.

Out of scope for MVP1:

- Route planning.
- Turn-by-turn navigation.
- Social ride sharing.
- Full AI tour-guide conversation.
- Europe-wide coverage.
- Car support.
- App Store launch polish.
- Deterministic offline place/boundary data.

MVP1 is the functional proof and trust-building step, not the full commercial thesis. It should prove that the app can run on a real ride, speak at useful moments, avoid distraction, and make riders want to try a richer RideHorizon. Willingness-to-pay testing should include the full tour-guide vision as well as the MVP1 feature set.

## Current Roadmap Decisions

Date: 2026-07-03

- Keep MVP1 defaults as `10 s` location check interval, Short Facts content mode, street off, and town, county, region, and country on.
- Defer the deterministic UK place context layer until after MVP1 field trial. Use Apple reverse geocoding plus proxy-backed facts for MVP1.
- Finish the Location screen before field trial. It should feel like the app's home, not a developer panel.
- Add first-time rider polish and app-quality review readiness before field trial.
- Stop the MVP1 build scope at Location screen completion plus first-time rider polish. The first field trial target is 2026-07-03.
- Add a near-term audio-quality task: choose a better installed iOS TTS voice, prefer enhanced/premium `en-GB` voices when available, and expose a small previewable voice setting.
- Use **announcements** as the standard user-facing word for RideHorizon speech. Avoid "utterances", "interruptions", "notifications", and navigation-style "guidance".
- Add ride-aware announcement timing after MVP1 field validation: delay place announcements while riding looks busy, such as hard braking, hard acceleration, cornering, rapid heading changes, or noisy GPS/course; speak the latest held announcement when stopped or riding steadily.
- Improve fact quality before broader testing: Short Facts should be 35-45 words, Long Facts should be 75-90 words, and both should assume an adult touring rider rather than explaining obvious schoolbook context.
- Treat fact quality as a ride-sequence problem, not only an isolated prompt problem. Add optional ride context so the proxy can avoid repeating regional setup across nearby towns.
- Add optional coarse home/familiar-region context and a later home quiet radius so the app can avoid facts near familiar places. Do not send an exact home address.
- Keep the implemented map-first Location screen and finish the remaining M6 items: nearby towns, previous street, stopped-only zoom presets, presentation tests, and field readability pass.
- Keep the long-term product narrative visible during validation: the app can range from silent to always-on guidance, with user-controlled detail and interests.
- Use `docs/product/strategy/TWO_WEEK_MARKET_VALIDATION_PLAN.md` as the current market-validation sprint after the deep-research report at `/Users/rob_dev/DocsLocal/motoguide/resources/RideHorizon_market_deep-research-report.md`.

## Milestone 0: Project Setup And Baseline Verification

Target outcome: the local checkout, docs, signing path, and test environment are understood.

Existing baseline:

- The repository is cloned at `/Users/rob_dev/DocsLocal/motoguide/repo`.
- `AGENTS.md` and `MILESTONES.md` exist in the repository root; milestone status records are in `docs/project/status/`.
- Xcode sees the `RideHorizon` scheme.
- CoreDevice has seen `Robert's iPhone` over the OTA path as `Roberts-iPhone-17.coredevice.local`; `xcodebuild -showdestinations` may not always list it.
- Xcode now has an iPhone 17 Pro Max simulator runtime available.

Remaining work:

- Keep Robert's iPhone unlocked, trusted, and on the same Wi-Fi as the Mac for OTA deploys.
- Re-run on the physical phone after any coherent app-code batch.
- Re-run simulator tests after any simulator launch issue is cleared.
- Keep `docs/project/status/MILESTONE_0_STATUS.md` updated with the latest pass/fail result.

Done when:

- RideHorizon launches on the iPhone.
- A simulator or device test run has a recorded result.
- Any remaining setup blocker is documented with exact command and expected result.

Primary command:

```bash
xcodebuild build -project /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj -scheme RideHorizon -destination 'id=00008150-000C70883E87401C' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData -allowProvisioningUpdates
```

Expected result: RideHorizon builds for Robert's iPhone.

## Milestone 1: Current Prototype Hardening

Target outcome: preserve the existing functionality while making it reliable enough for repeated development and road testing.

Existing baseline:

- Address formatting is separated from `LocationManager`.
- Announcement decision logic is separated from live iOS services.
- Test coordinates are explicit in `TestRouteFixture`.
- The view no longer owns duplicate speech synthesis.
- Tests cover core address, announcement, route, and interval behaviour.

Enhancement work:

- Replace placeholder generated tests in `RideHorizonTests.swift` with useful smoke tests or remove them.
- Add tests for `speakAfterEveryGeocode` semantics.
- Add tests for first-address behaviour when repeat toggles are disabled.
- Add tests for audio-interruption resume behaviour if the logic is extracted enough to test.
- Consider dependency injection for geocoding and speech so `LocationManager` can be tested without live `CLGeocoder` or `AVSpeechSynthesizer`.
- Decide whether `requestAlwaysAuthorization()` should happen on init or after an explicit user action.

Done when:

- Existing behaviour is covered by meaningful tests.
- No milestone asks future agents to re-separate code that is already separated.
- Test mode still advances through the Gloucestershire route.
- The app still speaks address changes.

## Milestone 2: Ride-Safe Announcement Rules

Target outcome: the current address-announcement system becomes an explicit ride-safe announcement policy.

Existing baseline:

- Location updates are throttled by `locationCheckInterval`.
- The UI exposes intervals from `1` to `300` seconds.
- The app can speak after every geocode or only when the address changes.
- Repeat toggles control street, town, county, and country output.

Enhancement work:

- Define MVP1 defaults for a real ride.
- Make "boundary-style" behaviour explicit: town, county, region, country.
- Decide whether street should be hidden by default for motorbike use.
- Add minimum-distance throttling in addition to time throttling.
- Add quiet mode.
- Add names-only mode.
- Add one-sentence mode for what is special about the current town or county.
- Rename UI controls from address-component language to rider-facing language where appropriate.
- Keep MVP1 as a separate geographic-awareness companion that runs alongside normal navigation.
- Add ride-aware announcement timing as a post-MVP1 enhancement: hold speech while the rider is cornering, braking, accelerating, rapidly changing heading, or otherwise in a busy riding state.
- Coalesce held announcements so RideHorizon speaks only the latest relevant place update, not a backlog.

Done when:

- Tests cover unchanged addresses, changed towns, changed counties, rapid updates, and small GPS movement.
- The UI exposes quiet, names-only, and one-sentence modes.
- The UI makes speech frequency rules visible.
- Default settings are conservative enough for a first road test.
- Ride-aware timing has explicit states and tests: announce normally, delay while busy, announce only when stopped or steady, and quiet.

## Milestone 3: Deferred UK Place Context Layer

Target outcome: RideHorizon can move beyond raw reverse-geocoded address text while preserving the existing reverse-geocode path as a fallback.

Status: Deferred until after MVP1 field trial.

MVP1 decision:

- Do not block the 2026-07-03 field trial on deterministic place data.
- Do not add offline boundary lookup, administrative polygons, or local place datasets before the first field trial.
- Keep current reverse geocoding as the MVP1 place hierarchy source.

Existing baseline:

- `CLGeocoder` provides street, town, county, and administrative area.
- The current test route is in Gloucestershire.

Enhancement work:

- Use the UK as the first region.
- Start with the area covered by the Gloucestershire test route.
- Choose a deterministic place/boundary source, such as OpenStreetMap-derived data or a government administrative boundary dataset.
- Define a small local data format for places, boundaries, and short labels.
- Add a lookup service that maps coordinates to place context.
- Keep reverse geocoding as a fallback when the deterministic lookup has no match.
- Add tests using known route coordinates.

Done when:

- Given test coordinates, the app can identify town or county context deterministically.
- The lookup service works offline for the first test region.
- The app can speak at least town and county changes from the new place context layer.

## Milestone 4: Real-Ride Audio Validation

Target outcome: the current prototype works on a real iPhone ride with helmet audio and normal navigation running separately.

Existing baseline:

- Background modes are declared.
- `AVAudioSession` is configured for playback with `mixWithOthers`.
- The app handles audio interruptions.
- The physical test phone is known: iPhone 17 Pro Max running iOS 26.5.1.
- The first headset is known: Nex Xcom Bluetooth headset based on Sena technology.

Enhancement work:

- Trust the developer certificate and launch on the phone.
- Validate location permission flow on-device.
- Validate background location behaviour.
- Validate spoken audio through the Nex Xcom headset.
- Validate speech while another navigation app is running.
- Record cases where speech is too frequent, too late, too quiet, or interrupted.
- Add a simple ride test checklist.

Done when:

- A real ride on the iPhone 17 Pro Max confirms background tracking and helmet audio work.
- Known failures are logged as issues or notes.
- The app can complete a short route without manual intervention.

## Milestone 5: Facts MVP

Target outcome: RideHorizon can add lightweight local context beyond names while keeping speech bounded and ride-safe.

Long-term interpretation reference: `docs/product/reference/HUMAN_MOTORCYCLE_TOUR_GUIDE_REFERENCE.md`. Milestone 5 delivers bounded place facts; it does not by itself deliver the passive contextual tour-guide level.

Existing baseline:

- The app can already speak selected place/address components.
- The proposed first-region route is known.
- Short Facts and Long Facts use the OpenAI-backed RideHorizon fact proxy as the primary implementation path.
- The proxy API contract is documented in `FACT_PROXY_OPENAPI.yaml`, with `docs/architecture/contracts/FACT_PROXY_CONTRACT.md` as the human-readable companion.

Enhancement work:

- Define short and long fact formats.
- Use the OpenAI-backed fact proxy first. Keep the iOS client and proxy server aligned with `FACT_PROXY_OPENAPI.yaml`.
- Keep `docs/architecture/plans/LOCAL_LLM_FACTS_FALLBACK_PLAN.md` as an alternative if OpenAI cost, latency, connectivity, privacy, or quality becomes a blocker.
- Add a content-depth parameter, including names only, Short Facts, and Long Facts.
- Revise fact length targets from the 2026-07-03 prompt-refinement pass:
  - Short Facts: 35-45 words, one sentence or two short sentences.
  - Long Facts: 75-90 words, two to four concise sentences, explicit and interruptible.
- Revise prompt style: avoid banal encyclopaedia facts, obvious administrative definitions, trivia without relevance, and patronising explanations. Prefer specific local history, landscape, road context, industry, architecture, border changes, notable people, or why the place matters.
- Add optional rider familiarity context to the contract, such as `homeCountry`, `homeRegion`, or `familiarRegions`, without sending an exact home address. Use it only to tune what not to explain.
- Add optional ride sequence context to the fact proxy contract: sequence index, current regional context, previous spoken places, previous topics, avoid topics, desired novelty, and familiarity policy.
- Add a small app-side topic memory for the last 3-5 spoken facts.
- Add optional `topics` and `novelty` fields to fact responses, or derive coarse tags on-device for MVP if the response contract stays simple.
- Add a home quiet radius setting after the first field trial: off, 5 miles, 10 miles, or 25 miles. Inside the radius, use silence or names-only unless the rider explicitly asks for facts.
- Add rules for when facts are spoken.
- Keep fact announcements shorter than navigation instructions.
- Keep prompt selection server-side; iOS sends only the requested fact mode and place hierarchy.
- Add tests for selecting and suppressing facts.
- Add fact-review fixtures using real route places and expected quality checks: not banal, not obvious to a UK rider, no schoolbook definitions, no safety instruction, no raw coordinates, bounded length, and low repetition across a ride sequence.

Done when:

- Short Facts speaks a place name plus one useful adult-level fact or short blurb when appropriate.
- Long Facts speaks a richer but bounded place blurb when selected.
- Names-only mode never speaks facts.
- Quiet mode remains silent.
- The fact instruction is constrained enough that announcements remain ride-safe.
- Facts use optional home/familiar-region context to avoid telling riders things they are likely to know already.
- Sequence tests show repeated nearby towns do not all restate the same regional topics, such as Cotswolds, limestone, stone buildings, wool, cloth, old routes, and mills.
- If no distinct fact is available for a same-region town, RideHorizon uses names-only or stays quiet rather than speaking filler.

## Milestone 5.5: Speech Voice And Audio Quality

Target outcome: RideHorizon sounds less robotic and more suitable for helmet listening.

Work:

- Keep installed Apple voices available as fallback.
- Add ElevenLabs speech through the proxy as the first non-Apple provider.
- Keep ElevenLabs API key, voice id, model id, and output format on the proxy only.
- Add a small Settings control for speech provider and keep a short preview phrase.
- Keep a sensible automatic default so a rider does not need to configure speech before first use.
- Test speech through the Nex Xcom headset, not only the phone speaker.
- Record selected provider, fallback voice name, identifier, quality, rate, pitch, and volume in a status note.

Done when:

- RideHorizon can use proxy-backed ElevenLabs speech and clearly falls back to Apple speech if it is unavailable.
- The rider can preview and choose the speech provider.
- The selected provider remains intelligible through the helmet at riding volume.

## Milestone 6: Location Screen Completion

Target outcome: riders can glance at the Location screen and understand where they are in the geographic hierarchy and relative to nearby towns, without turn-by-turn navigation.

Design reference: `docs/architecture/design/MAP_SITUATIONAL_AWARENESS.md`

Existing baseline:

- `LocationManager` provides throttled coordinates and reverse-geocoded `Address`.
- `BoundaryType` and `AnnouncementPolicy` define the street → town → county → region → country hierarchy.
- `ContentView` has a primary map-first Location screen with toolbar Settings and Log.
- The app already shows a compact overlay with current-place summary, context line, last spoken phrase, quiet-mode status, visible location/geocoder states, follow/recentre behaviour, manual pan/zoom controls, and a full-screen MapKit map.

Enhancement work:

- Complete the remaining **Location** screen context around the map-first implementation.
- Keep information compact: avoid a tall stacked dashboard above the map; use one-line current place, compressed hierarchy chips/rows, and collapsible detail.
- Show summary line, hierarchy panel, previous street when changed, and nearby towns with distances in compact overlay form.
- Auto-follow user location with context-aware default zoom.
- Keep speed-gated zoom presets when stopped.
- Reuse shared `LocationManager` state; support test mode on the Gloucestershire fixture.
- Do **not** add deterministic boundary data or administrative polygons in M6.
- Use `MKLocalSearch` (or equivalent) for nearest-town context; geocoder for hierarchy text.
- Extract testable pure functions for summary, hierarchy rows, and distance/bearing formatting.
- Show Quiet mode indicator on Location when announcements are muted.
- Disable map pan/zoom interaction while moving.

Done when:

- Location screen displays current hierarchy from live or test-mode location.
- Nearby towns list updates sensibly without excessive network calls.
- Map interaction is limited while moving; zoom presets work when stopped.
- Unit tests cover hierarchy presentation and nearby-town formatting logic.
- A rider can orient themselves at a brief stop without using a navigation app.
- Design doc open questions are resolved or logged as follow-ups.

## Milestone 6.5: First-Time Rider Polish And Review Readiness

Target outcome: RideHorizon feels like a focused rider app, not a developer test harness, and avoids obvious App Store review problems before broader testing.

Design reference: `docs/product/plans/MVP_POLISH_PLAN.md`

Work:

- Keep onboarding short: purpose, not navigation, helmet audio, background location, and what the rider will hear.
- Request location permission only after the app explains why it is needed.
- Make the Location screen the first screen.
- Split Settings into simple controls and Advanced developer/tuning controls.
- Hide or collapse Test Mode, Speak After Every Geocode, Bluetooth delay, and proxy diagnostics.
- Surface permission, GPS, geocoder, proxy, and audio-session failures in the UI with short recovery actions.
- Rename rider-visible copy from internal terms to rider terms: road, town, county, region, country, Short Facts, Quiet.
- Make the Log rider-readable as History while keeping enough detail for field debugging.
- Audit Info.plist background modes and permission strings before App Store or TestFlight review.
- Draft App Review notes that explain the demo route, background location use, helmet audio use, and proxy-backed facts.
- Draft privacy notes for location use, fact proxy requests, retention, and deletion/consent expectations.

Done when:

- A new rider can launch, understand the app, allow location, and see live status without a developer briefing.
- Debug/tuning controls are not in the primary path.
- The app explains when it is waiting for permission, GPS, geocoding, audio, or proxy facts.
- Apple review risks are documented: background location, background audio, privacy details, backend availability, and generated fact content.
- The app is ready to install on the physical iPhone for the 2026-07-03 field trial.

## Milestone 7: Custom Announcement Instructions

Target outcome: RideHorizon can adapt announcement style without making the ride experience unsafe or noisy.

Enhancement work:

- Expose a controlled rider preference field for announcement fact focus.
- Support different instruction presets by boundary type, such as town, county, region, country, landmark, and history.
- Add guardrails for maximum sentence count and maximum spoken duration.
- Add tests for rider preferences that are too long, too vague, or unsafe.

Done when:

- A rider can choose or edit announcement preferences.
- The app still limits output to the selected content depth.
- Boundary-specific preferences do not bypass safety limits.

## Milestone 7.5: Ride-Aware Announcement Timing

Target outcome: RideHorizon speaks at calmer moments and avoids blithering away while the rider is dealing with demanding riding conditions.

Vocabulary:

- Use **announcements** for rider-facing copy.
- Use **ride-aware announcements** for the feature.
- Use **held announcement** internally for a delayed speech item.

Work:

- Define a `RideState` model from available signals: stopped, slow and steady, moving steadily, cornering, braking, accelerating, and uncertain.
- Use speed, course/heading stability, acceleration, and turn-rate signals where available. Do not depend on perfect lean-angle detection for MVP.
- Add Settings options:
  - Announce normally.
  - Delay while cornering or braking.
  - Announce only when stopped or riding steadily.
  - Quiet mode.
- Delay place announcements while the ride state is busy or uncertain, then speak the latest held announcement when conditions settle.
- Coalesce held announcements. Keep only the most relevant latest boundary/fact; do not read a backlog after a bend or junction sequence.
- Add a maximum hold time, then either speak a shortened names-only update or drop it.
- Keep navigation-app audio priority in mind. RideHorizon must remain secondary to turn-by-turn directions.
- Add tests for busy-state suppression, steady-state release, max-hold expiry, quiet-mode override, and coalescing.

Done when:

- RideHorizon can delay speech while cornering, braking, accelerating, rapidly changing heading, or receiving noisy motion/course data.
- The rider can choose a conservative timing mode without understanding the sensors.
- Held announcements do not become stale, unsafe, or repetitive.
- The feature is validated on the physical iPhone and Nex Xcom headset during a real ride.

## Milestone 8: MVP1 Field Trial

Target outcome: decide whether the separate geographic-awareness companion, including its optional audio, is useful enough to continue.

First field trial target: 2026-07-03.

Build-scope stop point:

- Stop feature work after Milestone 6 and Milestone 6.5 are ready enough for one real ride.
- Do not add deterministic place data, open-ended rider questions, listening, POI handoff, accounts, analytics, or route planning before this field trial.

Work:

- Run several rides on familiar and unfamiliar roads.
- Compare against normal navigation alone.
- Capture rider notes immediately after each ride.
- Evaluate distraction, timing, usefulness, novelty, and headset reliability.
- Move the fact proxy from the default `ridehorizon.digitalmercenaries.ai` hostname to an owned RideHorizon/DML domain name before inviting broader external testers.
- Decide whether to continue, pivot, or stop.

Done when:

- First checkpoint: one ride report from 2026-07-03 records whether GPS, background behavior, helmet audio, fact timing, and Location screen status worked.
- There are at least 3 ride reports.
- MVP1 defaults have been adjusted from real use.
- The next build direction is explicit.

## Milestone 9: MVP2 Listening And POI Handoff

Target outcome: RideHorizon adds the first controlled interactive-guide layer above passive place announcements. It can listen for simple rider replies, suggest nearby points of interest, give a short or longer description when appropriate, learn from expressed interests, and hand off a selected destination to navigation.

Interaction reference: `docs/product/reference/INTERACTIVE_TOUR_GUIDE_REFERENCE.md`.

MVP2 product boundary:

- This is still not route planning. RideHorizon may help pick a destination, then hand off to a navigation app.
- Listening should be explicit and bounded, not always-on open conversation.
- This is the first controlled interactive-guide increment. The passive guide's continuously context-aware behaviour remains a separate capability and prerequisite.
- POI suggestions should be sparse and rider-relevant: castles, viewpoints, historic places, cafes, fuel, museums, bridges, passes, border points, or landmarks.
- Longer descriptions should be available when stopped or explicitly requested, not pushed automatically while riding.
- The first implementation can use server/API data or pre-generated touring-pack content. Live LLM use is allowed only if cost, latency, and privacy are visible in the product and business model.

Work:

- Add a limited listening mode for short replies such as "yes", "no", "next", "tell me more", and "navigate there".
- Let RideHorizon suggest a nearby point of interest from the current place context.
- Support a short list flow: "There are three nearby places: Caernarfon Castle, the waterfront, and Segontium Roman Fort."
- Support a detail flow: "Tell me more about Caernarfon Castle" gives a longer but bounded description, preferably when stopped.
- Support a navigation flow: "Navigate to Caernarfon Castle" opens or hands off to the chosen navigation app with the selected POI.
- Define the first navigation handoff target before implementation, likely Google Maps or Apple Maps, then test Garmin/TomTom/Calimoto feasibility later.
- Keep fallback behaviour simple if navigation handoff fails: show the destination and copy/open action, do not attempt route calculation.
- Add user controls for whether POI suggestions are enabled, when listening is allowed, and whether long descriptions can play while moving.
- Add simple preference signals such as "more like this", "less history", "shorter", "more detail", or topic toggles so the guide can begin adapting without needing broad memory first.
- Add validation questions before implementation: would riders use ask-back while moving, only when stopped, or not at all?

Done when:

- The app can suggest one or more POIs grounded in current location.
- The rider can accept, reject, ask for the next option, ask for more detail, or request navigation using simple voice commands.
- The app can pass the selected POI to the chosen navigation flow without becoming a route planner.
- Long descriptions are bounded, interruptible, and disabled or deferred while moving unless explicitly allowed.
- Listening does not interfere with core boundary announcements, normal navigation audio, or instant mute.

## Milestone 10: Rider Questions

Target outcome: RideHorizon can capture explicit spoken questions through the microphone and answer constrained place questions after the simpler listening and POI-handoff patterns are validated, then progressively expand toward an interactive adaptive guide.

Interaction reference: `docs/product/reference/INTERACTIVE_TOUR_GUIDE_REFERENCE.md`.

Boundary:

- This is a later expansion of MVP2, not MVP1.
- Prefer questions about the current place, nearby POIs, route-adjacent context, or the last announced place.
- Avoid general chat, route advice, safety advice, speed advice, or broad travel planning while riding.
- Defer open-ended or long answers until stopped unless the rider explicitly allows a longer response.
- General questions are part of the long-term product vision, but should be introduced behind controls and tested against distraction, latency, answer quality, and trust.

Work:

- Add a constrained question mode, for example: "What is that castle?", "Anything worth visiting nearby?", "Why is this town notable?", or "Tell me more when I stop."
- Make microphone listening explicit, visibly and audibly bounded, cancellable and off by default outside a deliberate interaction window.
- Ground answers in current place context, selected POI, trusted source text, cached touring-pack content, or proxy/API content.
- Keep answers short by default and make longer answers explicit.
- Add a way to defer longer answers until the ride stops.
- Add privacy and cost controls if live LLM calls are used.
- Test whether riders prefer passive announcements, stopped-only questions, or moving voice questions before building broad Q&A.

Done when:

- The rider can ask basic questions about the current town, county, landmark, or history.
- Answers stay within ride-safe length limits.
- The feature can be disabled completely.
- The implementation shows whether open-ended questions add enough value beyond POI suggestion and navigation handoff.

## Milestone 11: Post-MVP Direction

Target outcome: choose the next product shape after validation.

Options:

- Deeper UK motorbike touring app.
- UK and Europe motorbike touring app.
- Car road-trip audio companion after motorbike validation.
- Integration layer for existing navigation.
- AI live-guide feature set with POI discovery, listening, questions, and navigation handoff.
- Adaptive always-on tour guide with rider memory, configurable detail, topic preferences, voice questions, and trip-aware suggestions.
- Stop after prototype if the ride value is weak.

Decision criteria:

- Does the rider miss RideHorizon when it is off?
- Does it add value without distraction?
- Is the data pipeline manageable?
- Can it run reliably in the background?
- Is the motorbike-specific niche strong enough?

## Immediate Next Steps

1. Integrate RH-055's documentation-only focus reconciliation.
2. Claim RH-024 Tier 1 on its own implementation branch.
3. Add bounded same-day delivered-fact context and coherent revisit behaviour without changing the stable cache into a rolling-history key.
4. Update and verify the app/proxy/OpenAPI contract with focused tests, then run one complete implementation checkpoint.
5. Return to the milestone health gate before selecting RH-025, RH-027 or any parked stream.

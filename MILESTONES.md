# MotoGuide High-Level Plan

Date: 2026-07-01

## Product Goal

Build MotoGuide into a real-ride iPhone audio companion that gives motorcyclists short, useful spoken place context while they follow their normal navigation app.

## Existing Baseline

The current codebase is not a blank slate. It already contains:

- A SwiftUI app with controls for test mode, speak-after-every-geocode, location check interval, repeated address components, and manual logging.
- `LocationManager`, which requests location, reverse-geocodes coordinates, throttles location updates by interval, handles background audio setup, and speaks with `AVSpeechSynthesizer`.
- `Address` and `AddressFormatter`, which separate address data and spoken text formatting.
- `AnnouncementDecision`, which decides whether to speak, which address components to include, and how repeat preferences behave.
- `TestRouteFixture`, a named Gloucestershire route with 11 fixed coordinates for manual and simulator testing.
- Unit tests for address formatting, announcement decisions, location interval throttling, test mode, and the route fixture.
- `Info.plist` background modes for audio, location, Bluetooth, fetch, processing, and external accessory support.

Treat this as the baseline. Do not re-plan work that is already implemented unless the milestone is about verification, hardening, or changing behaviour.

## Scope

In scope for MVP1:

- iOS app.
- UK motorbike use case.
- Separate audio companion alongside normal navigation.
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

## Milestone 0: Project Setup And Baseline Verification

Target outcome: the local checkout, docs, signing path, and test environment are understood.

Existing baseline:

- The repository is cloned at `/Users/rob_dev/DocsLocal/motoguide/repo`.
- `AGENTS.md`, `MILESTONES.md`, and `MILESTONE_0_STATUS.md` exist in the repository root.
- Xcode sees the `MotoGuide` scheme.
- Xcode sees `Robert's iPhone` as a physical iOS destination.
- Xcode now has an iPhone 17 Pro Max simulator runtime available.

Remaining work:

- Trust the developer certificate on the iPhone.
- Re-run on the physical phone after trust is granted.
- Re-run simulator tests after any simulator launch issue is cleared.
- Keep `MILESTONE_0_STATUS.md` updated with the latest pass/fail result.

Done when:

- MotoGuide launches on the iPhone.
- A simulator or device test run has a recorded result.
- Any remaining setup blocker is documented with exact command and expected result.

Primary command:

```bash
xcodebuild build -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'id=00008150-000C70883E87401C' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData -allowProvisioningUpdates
```

Expected result: MotoGuide builds for Robert's iPhone.

## Milestone 1: Current Prototype Hardening

Target outcome: preserve the existing functionality while making it reliable enough for repeated development and road testing.

Existing baseline:

- Address formatting is separated from `LocationManager`.
- Announcement decision logic is separated from live iOS services.
- Test coordinates are explicit in `TestRouteFixture`.
- The view no longer owns duplicate speech synthesis.
- Tests cover core address, announcement, route, and interval behaviour.

Enhancement work:

- Replace placeholder generated tests in `MotoGuideTests.swift` with useful smoke tests or remove them.
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
- Keep MVP1 as a separate audio companion that runs alongside normal navigation.

Done when:

- Tests cover unchanged addresses, changed towns, changed counties, rapid updates, and small GPS movement.
- The UI exposes quiet, names-only, and one-sentence modes.
- The UI makes speech frequency rules visible.
- Default settings are conservative enough for a first road test.

## Milestone 3: UK Place Context Layer

Target outcome: MotoGuide can move beyond raw reverse-geocoded address text while preserving the existing reverse-geocode path as a fallback.

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

## Milestone 5: Short Facts MVP

Target outcome: MotoGuide can add lightweight local context beyond names while keeping speech short.

Existing baseline:

- The app can already speak selected place/address components.
- The proposed first-region route is known.
- Short Facts currently use the OpenAI-backed MotoGuide fact proxy as the primary implementation path.
- The proxy API contract is documented in `FACT_PROXY_OPENAPI.yaml`, with `FACT_PROXY_CONTRACT.md` as the human-readable companion.

Enhancement work:

- Define a short fact format.
- Use the OpenAI-backed fact proxy first. Keep the iOS client and proxy server aligned with `FACT_PROXY_OPENAPI.yaml`.
- Keep `LOCAL_LLM_FACTS_FALLBACK_PLAN.md` as an alternative if OpenAI cost, latency, connectivity, privacy, or quality becomes a blocker.
- Add a content-depth parameter, starting with names only and one sentence.
- Add rules for when facts are spoken.
- Keep fact announcements shorter than navigation instructions.
- Add an internal prompt or instruction field for generating or selecting local facts.
- Add tests for selecting and suppressing facts.

Done when:

- One-sentence mode speaks a place name plus one concise fact when appropriate.
- Names-only mode never speaks facts.
- Quiet mode remains silent.
- The fact instruction is constrained enough that announcements remain short.

## Milestone 6: Situational Awareness Map

Target outcome: riders can glance at a Map tab and understand where they are in the geographic hierarchy and relative to nearby towns, without turn-by-turn navigation.

Design reference: `MAP_SITUATIONAL_AWARENESS.md`

Existing baseline:

- `LocationManager` provides throttled coordinates and reverse-geocoded `Address`.
- `BoundaryType` and `AnnouncementPolicy` define the street → town → county → nation → country hierarchy.
- `ContentView` has Settings and Log tabs only; no MapKit usage yet.

Enhancement work:

- Add a **Map** tab (proposed default) with a single MapKit map and a context stack above it.
- Show summary line, hierarchy panel, previous street (when changed), and nearest towns with distances.
- Auto-follow user location with context-aware default zoom; speed-gated zoom presets when stopped.
- Reuse shared `LocationManager` state; support test mode on the Gloucestershire fixture.
- Do **not** add administrative boundary polygons in M6 — defer to Milestone 3.
- Use `MKLocalSearch` (or equivalent) for nearest-town context; geocoder for hierarchy text.
- Extract testable pure functions for summary, hierarchy rows, and distance/bearing formatting.
- Show Quiet mode indicator on Map when announcements are muted.
- Disable map pan/zoom interaction while moving.

Done when:

- Map tab displays current hierarchy from live or test-mode location.
- Nearby towns list updates sensibly without excessive network calls.
- Map interaction is limited while moving; zoom presets work when stopped.
- Unit tests cover hierarchy presentation and nearby-town formatting logic.
- A rider can orient themselves at a brief stop without using a navigation app.
- Design doc open questions are resolved or logged as follow-ups.

## Milestone 7: Custom Announcement Instructions

Target outcome: MotoGuide can adapt announcement style without making the ride experience unsafe or noisy.

Enhancement work:

- Expose a controlled custom instruction field for announcement preferences.
- Support different instruction presets by boundary type, such as town, county, region, country, landmark, and history.
- Add guardrails for maximum sentence count and maximum spoken duration.
- Add tests for custom instructions that are too long, too vague, or unsafe.

Done when:

- A rider can choose or edit announcement preferences.
- The app still limits output to the selected content depth.
- Boundary-specific preferences do not bypass safety limits.

## Milestone 8: MVP1 Field Trial

Target outcome: decide whether the separate audio companion is useful enough to continue.

Work:

- Run several rides on familiar and unfamiliar roads.
- Compare against normal navigation alone.
- Capture rider notes immediately after each ride.
- Evaluate distraction, timing, usefulness, novelty, and headset reliability.
- Move the fact proxy from the default `motoguide-fact-proxy.fly.dev` hostname to an owned MotoGuide/DML domain name before inviting broader external testers.
- Decide whether to continue, pivot, or stop.

Done when:

- There are at least 3 ride reports.
- MVP1 defaults have been adjusted from real use.
- The next build direction is explicit.

## Milestone 9: MVP2 Listening And POI Handoff

Target outcome: MotoGuide can listen for simple rider replies and hand off a selected point of interest to navigation.

Work:

- Add a limited listening mode for short replies.
- Let MotoGuide suggest a nearby point of interest.
- Let the rider accept, reject, or ask for the next option.
- Define the first navigation handoff target.
- Keep fallback behaviour simple if navigation handoff fails.

Done when:

- The app can suggest a POI and process a simple voice reply.
- The app can pass the selected POI to the chosen navigation flow.
- Listening does not interfere with core boundary announcements.

## Milestone 10: Rider Questions

Target outcome: MotoGuide can answer simple place questions during a ride.

Work:

- Add a constrained question mode.
- Ground answers in the current place context and local content dataset.
- Keep answers short by default.
- Add a way to defer longer answers until the ride stops.

Done when:

- The rider can ask basic questions about the current town, county, landmark, or history.
- Answers stay within ride-safe length limits.
- The feature can be disabled completely.

## Milestone 11: Post-MVP Direction

Target outcome: choose the next product shape after validation.

Options:

- Deeper UK motorbike touring app.
- UK and Europe motorbike touring app.
- Car road-trip audio companion after motorbike validation.
- Integration layer for existing navigation.
- AI live-guide feature set with listening and questions.
- Stop after prototype if the ride value is weak.

Decision criteria:

- Does the rider miss MotoGuide when it is off?
- Does it add value without distraction?
- Is the data pipeline manageable?
- Can it run reliably in the background?
- Is the motorbike-specific niche strong enough?

## Immediate Next Steps

1. Trust the developer certificate on the iPhone.
2. Launch MotoGuide on the iPhone from Xcode.
3. Record the launch result in `MILESTONE_0_STATUS.md`.
4. Run simulator tests again or record the remaining simulator launch blocker.
5. Start Milestone 1 by replacing placeholder tests and adding tests for current speech modes.

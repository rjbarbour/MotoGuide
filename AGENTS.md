# MotoGuide Agent Instructions

Use plain language, direct instructions, no waffle. Use ISO-8601 dates.

## Project Purpose

MotoGuide is a motorbike-specific audio guide for riders. It runs alongside normal navigation and speaks short, useful place context through a Bluetooth helmet headset.

The product is not a route planner. It is an ambient place-awareness companion.

Primary user: a touring motorcyclist on long rides, international trips, or unfamiliar routes.

Core value: help the rider know where they are and why it matters without looking at a screen.

## Current Product Shape

The existing GitHub prototype is an iOS SwiftUI app:

- Repository: `https://github.com/rjbarbour/MotoGuide.git`
- Local checkout: `/Users/rob_dev/DocsLocal/motoguide/repo`
- Main app: `/Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide/`
- Core location and speech logic: `/Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide/LocationManager.swift`
- Main SwiftUI screen: `/Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide/ContentView.swift`
- Address model and formatter: `/Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide/Address.swift`
- Announcement decision logic: `/Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide/AnnouncementDecision.swift`
- Manual test route fixture: `/Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide/TestRouteFixture.swift`

Current prototype capabilities:

- Request iOS location updates.
- Reverse-geocode coordinates into address components.
- Format selected address components into spoken text.
- Decide whether to speak based on address changes, repeat preferences, and speak-after-every-geocode mode.
- Speak address changes using iOS text-to-speech.
- Support background audio and location modes.
- Provide a test mode with named Gloucestershire route coordinates.
- Unit-test address formatting, announcement decisions, location interval throttling, test mode, and the route fixture.

Current interface controls:

- `Test Mode`
- `Speak After Every Geocode`
- `Location Check Interval (seconds)`: `1`, `2`, `5`, `10`, `15`, `30`, `60`, `120`, `300`
- `Repeat Street`
- `Repeat Town`
- `Repeat County`
- `Repeat Country`
- Manual `Log`

## Product Definition

Use this definition when making product or architecture decisions:

- MotoGuide monitors the rider's live location.
- It detects meaningful location changes, especially town, county, region, country, and later landmarks.
- It speaks short announcements through helmet audio.
- It must avoid distracting the rider.
- It must run alongside existing navigation apps.
- It should avoid route calculation unless explicitly added later.

## MVP Boundary

Build the MVP as one narrow mobile prototype:

1. Run during a ride.
2. Monitor GPS location.
3. Detect town or county changes.
4. Speak short place announcements through Bluetooth audio.
5. Offer three modes:
   - Names only.
   - Short facts.
   - Quiet mode.

Do not expand into general travel planning, route planning, social ride tracking, or full AI tour guiding until MVP1 works on real rides.

## Product Decisions

### MVP1

- Target motorbikes only.
- Start with the UK.
- Run as a separate audio companion alongside normal navigation.
- Speak on meaningful boundary changes, using the existing app pattern of location interval plus repeat controls.
- Support configurable content depth: names only, one sentence, or more detail.
- Add one sentence about what is special about the current town or county as the first content expansion beyond names.
- Test with a Nex Xcom Bluetooth headset, based on Sena technology.
- Test on the user's iPhone 17 Pro Max running iOS 26.5.1.

### MVP2

- Add listening and navigation handoff.
- Example flow: MotoGuide suggests a point of interest and the rider replies to navigate there.
- Choose the first navigation app or handoff target before implementation.

### Later Versions

- Add open-ended rider questions.
- Expose custom instructions for announcement style and content preferences.
- Support different instructions by boundary type, such as town, county, region, country, landmark, or history.
- Expand from UK-only to UK and Europe.
- Add car support after the motorbike use case is validated.

Open questions:

- What are the default interval, repeat, and content-depth settings for a real ride?
- How should custom instructions be constrained so rider-facing speech stays short and safe?
- Which navigation apps should MVP2 target first for POI handoff?

## Related Local Context

Focus Planner context:

- Local folder: `/Users/rob_dev/DocsLocal/focus_planner`
- Trello export: `/Users/rob_dev/DocsLocal/focus_planner/bmWfhK1S - robs-todo.json`
- Relevant cards:
  - `#448 MotoGuide App`
  - `#449 Test cursor and Claude with MotoGuide`
  - `#455 Project (iPhone app, MotoGuide project)`

ICB catalogue context:

- Local repo: `/Users/rob_dev/DocsLocal/digital-mercenaries-ltd/icb-catalogue`
- GitHub repo: `https://github.com/rjbarbour/icb-catalogue-processing.git`
- MotoGuide ICB: `/Users/rob_dev/DocsLocal/digital-mercenaries-ltd/icb-catalogue/staged_icbs/6a1047a6a591ed37d9fd4e0e.md`

## Working Rules

- Preserve rider safety as a first-order requirement.
- Keep speech short, sparse, and interruptible.
- Prefer deterministic location logic before AI-generated content.
- Keep routing separate from place awareness.
- Add tests around location-change detection, announcement throttling, and speech text generation.
- Use simulator tests for logic, but validate Bluetooth/audio/background behavior on a real iPhone before calling it done.
- The primary physical test device is an iPhone 17 Pro Max running iOS 26.5.1.
- Do not commit secrets, Trello exports, personal ride logs, location history, or private notes.

## Commands

Clone the GitHub project into the permanent working-copy subfolder:

```bash
git clone https://github.com/rjbarbour/MotoGuide.git /Users/rob_dev/DocsLocal/motoguide/repo
```

Expected result: `/Users/rob_dev/DocsLocal/motoguide/repo` contains `.git`, `MotoGuide.xcodeproj`, `MotoGuide/`, `MotoGuideTests/`, and `MotoGuideUITests/`.

Open the Xcode project:

```bash
open /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj
```

Expected result: Xcode opens the MotoGuide project.

Run tests from the command line after the project is cloned:

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected result: the MotoGuide unit and UI test targets build and run in the iOS Simulator.

Inspect the MotoGuide ICB:

```bash
sed -n '1,220p' /Users/rob_dev/DocsLocal/digital-mercenaries-ltd/icb-catalogue/staged_icbs/6a1047a6a591ed37d9fd4e0e.md
```

Expected result: prints the 11-section Idea Capture Brief for MotoGuide.

Search Focus Planner for MotoGuide cards:

```bash
jq -r '.cards[]? | select((.name + " " + (.desc // "")) | test("motoguide|moto guide"; "i")) | [.idShort, .name, .dateLastActivity] | @tsv' '/Users/rob_dev/DocsLocal/focus_planner/bmWfhK1S - robs-todo.json'
```

Expected result: prints the MotoGuide-related Trello cards.

## Documentation Rules

- Use ISO-8601 dates, for example `2026-07-01`.
- Put planning documents in the repository root unless there is a clearer existing docs structure.
- Keep milestone plans high level unless the user asks for implementation tickets.
- Record assumptions explicitly.
- When giving commands, include the exact command and expected result.

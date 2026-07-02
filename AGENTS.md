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
- Core modules: `LocationManager.swift`, `AnnouncementPolicy.swift`, `Address.swift`, `ProxyFactGenerator.swift`, `FirstRunState.swift`
- UI: `ContentView.swift` (primary Location screen with toolbar Settings and Log), `OnboardingView.swift`
- Test route: `TestRouteFixture.swift` (Gloucestershire waypoints)

Current prototype capabilities:

- Onboarding on first launch; developer reset under Settings → Advanced → Developer.
- Location tracking starts after onboarding (not on raw app init).
- Reverse-geocode coordinates into street, town, county, region, and country.
- Natural announcement phrasing, e.g. `Welcome to Wales. You are in Chepstow, Monmouthshire`.
- Announcement modes: Natural, Names Only, Short Facts (proxy-backed LLM), Long Facts (proxy-backed LLM), Quiet.
- Single-slot announcement queue with Bluetooth audio delay.
- Boundary priority: country → nation → county → town → street.
- Test mode with named Gloucestershire route coordinates.
- Unit tests for address, announcements, facts (mocked), first-run state, and route fixture.
- Short/Long Facts OpenAPI contract: `FACT_PROXY_OPENAPI.yaml`.

Current interface:

- Location is the primary screen.
- Toolbar gear opens Settings.
- Toolbar history/list button opens Log.
- Settings top level: announcement style and what to announce.
- Settings Advanced: location check frequency, Test Mode, Speak After Every Geocode, Bluetooth delay, proxy diagnostics, reset onboarding.

Log: scrollable history and manual test/current-location log button.

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
- Validate Bluetooth/audio/background behavior on the physical iPhone before calling ride-facing work done.
- The primary physical test device is an iPhone 17 Pro Max running iOS 26.5.1.
- Do not commit secrets, Trello exports, personal ride logs, location history, or private notes.

## Development Workflow

All agents work in one checkout: `/Users/rob_dev/DocsLocal/motoguide/repo`. There are no separate worktrees unless explicitly created.

- Work on one coherent batch of changes at a time. Do not run parallel agents that edit the same repo.
- Do not run multiple `xcodebuild` jobs in parallel against the same `DerivedData` path.
- Prefer writing and compiling over repeated full test/deploy cycles.

### Default loop

Batch changes, then validate once:

1. Implement a coherent chunk of work (feature slice, bugfix, or polish group).
2. Run a compile check (`xcodebuild build` for the physical device destination).
3. Deploy to the iPhone if connected (see Device Deploy).
4. Run the simulator unit test suite only at meaningful checkpoints — not after every small edit.

### When to run simulator tests

Run `xcodebuild test` when:

- Announcement, location, or speech logic changed and tests were added or updated.
- A milestone slice is complete.
- The user asks for tests, or before a commit the user requested.

Skip simulator tests when:

- Only docs, copy, or comments changed.
- Small UI tweaks with no logic change.
- Mid-batch work that will be validated at the end of the batch.

iOS unit tests require a simulator or device test host. There is no separate fast non-simulator XCTest path for this app today.

### Phone vs simulator

| Step | Prefer |
|------|--------|
| Manual check (speech, Bluetooth, UI) | Physical iPhone |
| Install after build | Physical iPhone |
| Automated unit tests | Simulator at checkpoints |
| Ride validation | Physical iPhone with helmet |

The simulator is slow to boot and run. The phone is faster for day-to-day “does it work” checks.

## Device Deploy

After a **coherent batch** of app code changes, build and install on the physical iPhone if it is connected. Do not wait for the user to ask. Do not deploy after every tiny edit within the same batch.

One build and one install per batch is enough.

Primary device:

```text
Robert's iPhone — id 00008150-000C70883E87401C
```

Check the device is available:

```bash
xcodebuild -showdestinations -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide 2>&1 | rg "Robert's iPhone"
```

Build, install, and launch:

```bash
xcodebuild build -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'platform=iOS,id=00008150-000C70883E87401C' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData -allowProvisioningUpdates

xcrun devicectl device install app --device 00008150-000C70883E87401C /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData/Build/Products/Debug-iphoneos/MotoGuide.app

xcrun devicectl device process launch --device 00008150-000C70883E87401C ai.dml.MotoGuide
```

Expected result: the latest build is on the phone and the app opens.

If the phone is not connected, say so briefly and continue. Do not block the task on device deploy failure.

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

Run unit tests on the simulator at a milestone or pre-commit checkpoint (not after every small change):

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData -only-testing:MotoGuideTests
```

Expected result: the MotoGuide unit test target builds and runs in the iOS Simulator.

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

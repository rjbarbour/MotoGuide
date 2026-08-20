# RideHorizon Agent Instructions

Use plain language, direct instructions, no waffle. Use ISO-8601 dates.

Whenever mentioning a tracked work item in user-facing text, give its identifier and a brief title or plain-language description. Never use a bare ticket identifier such as `RH-024` without explaining what the work item is.

## Workspace Scope

This repository is the canonical workspace for working on the RideHorizon codebase.

Use this repository for:

- app and service code;
- tests, builds, releases and deployment tooling;
- architecture and refactoring plans that govern code changes;
- implementation-linked technical documentation; and
- tracked software delivery through the repository's canonical ledger.

Use the parent workspace, `/Users/rob_dev/DocsLocal/motoguide`, for RideHorizon research, discovery, market and competitor analysis, exploratory validation, and supporting source material that does not need to ship with the codebase.

When research produces an accepted product requirement, architectural decision or implementation constraint, transfer the durable outcome into the appropriate repository document or ledger record before implementation. Do not treat unintegrated parent-workspace research as implementation authority.

## Project Purpose

RideHorizon is a motorbike-specific geographic-awareness companion. It runs alongside normal navigation, shows the rider's best-available current place and can add short, useful place context through a Bluetooth helmet headset.

The product is not a route planner. It is an ambient place-awareness companion.

Primary user: a touring motorcyclist on long rides, international trips, or unfamiliar routes.

Core value: restore the geographic context that turn-by-turn navigation omits—where the rider is now, what kind of place they are travelling through and why it matters. The visual Location screen is independently useful; optional audio delivers the same core value without requiring the rider to look at the screen.

Long-term vision: RideHorizon can range from silent display-only geographic awareness, through sparse boundary and place announcements, to a passive contextual tour guide and then an interactive guide. The rider controls frequency, length, topics and detail level. Later versions should learn what the rider is interested in, answer spoken place questions, refine the guide from rider instructions, suggest worthwhile stops and hand selected destinations to an existing navigation app. "Always-on guide" means continuously context-aware passive guidance; it does not imply an always-listening microphone.

## Current Product Shape

The existing GitHub prototype is an iOS SwiftUI app:

- Repository: `https://github.com/rjbarbour/MotoGuide.git`
- Local checkout: `/Users/rob_dev/DocsLocal/motoguide/repo`
- Main app: `/Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon/`
- Core modules: `LocationManager.swift`, `AnnouncementPolicy.swift`, `Address.swift`, `ProxyFactGenerator.swift`, `FirstRunState.swift`
- UI: `ContentView.swift` (primary Location screen with toolbar Settings and Log), `OnboardingView.swift`
- Test route: `TestRouteFixture.swift` (Gloucestershire waypoints)

Current prototype capabilities:

- Onboarding on first launch; developer reset under Settings → Advanced → Developer.
- Location tracking starts after onboarding (not on raw app init).
- Reverse-geocode coordinates into street, town, county, region, and country.
- Natural announcement phrasing, e.g. `Welcome to Wales. You are in Chepstow, Monmouthshire`.
- Announcement modes: Natural, Names Only, Short Facts (proxy-backed LLM), Long Facts (proxy-backed LLM), Quiet.
- Single-slot announcement queue with Bluetooth audio delay and primary-audio interruption handling.
- Boundary priority: country → nation → county → town → street.
- Rider context fields for home country, home region, familiar regions, fact interests, and custom fact focus.
- Speech provider setting with Apple voice selection/preview and proxy-backed ElevenLabs option.
- Map-first Location screen with compact overlay, follow/recentre behaviour, manual pan/zoom controls, and visible location/geocoder states.
- Test mode with named Gloucestershire route coordinates.
- Unit tests for address, announcements, facts (mocked), first-run state, and route fixture.
- Short/Long Facts OpenAPI contract: `FACT_PROXY_OPENAPI.yaml`.

Current interface:

- Location is the primary screen.
- Toolbar gear opens Settings.
- Toolbar history/list button opens Log.
- Settings top level: Quiet Mode, announcement style, voice, speech provider, what to announce, and rider context.
- Settings Advanced: location check frequency, map label scale, Bluetooth delay, custom fact focus, Developer controls for Test Mode, Speak After Every Geocode, proxy diagnostics, and reset onboarding.

Log: scrollable history and manual test/current-location log button.

## Speech and content terminology

Use these terms consistently in product discussions, code, logs, and tests:

- **Fact**: the place-related information generated or selected for the rider.
- **Announcement text**: the rider-facing text prepared from the fact and any location context.
- **Text-to-speech (TTS)**: the process of sending announcement text to ElevenLabs (or an Apple voice) for vocalisation.
- **Synthesised speech audio**: the audio returned by the TTS provider. Use **speech audio** as the short form.
- **Audio stream** or **audio chunks**: use only when the provider returns the speech audio incrementally rather than as one complete file.
- **MP3 audio**: use when describing the current encoded transport or file format, not as the general product term.
- **Utterance**: the text intended to be spoken, not the audio returned by TTS. Avoid using it for the returned file.

The canonical pipeline is: **fact → announcement text → TTS → synthesised speech audio → playback**.

Recommended identifiers are `announcementText`, `speechAudio`, `SpeechAudioChunk`, and `speechAudioPlayer` where those distinctions are needed.

## Product Definition

Use this definition when making product or architecture decisions:

- RideHorizon monitors the rider's live location and maintains a best-available place estimate.
- It displays the current place and geographic hierarchy as the core awareness experience.
- It detects meaningful location changes, especially town, county, region, country, and later landmarks.
- It can optionally speak short announcements through helmet audio.
- It must avoid distracting the rider.
- It must run alongside existing navigation apps.
- It should avoid route calculation unless explicitly added later.

## MVP Boundary

Build the MVP as one narrow mobile prototype:

1. Run during a ride.
2. Monitor GPS location.
3. Display the best-available current place and geographic hierarchy.
4. Detect town or county changes.
5. Optionally speak short place announcements through Bluetooth audio.
6. Offer three modes:
   - Names only.
   - Short facts.
   - Quiet mode.

Do not expand into general travel planning, route planning, social ride tracking, or full AI tour guiding until MVP1 works on real rides.

MVP1 is a functional proof and private-beta learning tool. Do not treat MVP1 as the whole commercial proposition. Use it to prove real-ride feasibility, safety, trust, and interest in the broader RideHorizon vision.

## Product Decisions

### MVP1

- Target motorbikes only.
- Start with the UK.
- Run as a separate geographic-awareness companion alongside normal navigation, with a map-first display and optional audio.
- Speak on meaningful boundary changes, using the existing app pattern of location interval plus repeat controls.
- Support configurable content depth: names only, one sentence, or more detail.
- Add one sentence about what is special about the current town or county as the first content expansion beyond names.
- Test with a Nex Xcom Bluetooth headset, based on Sena technology.
- Test on the user's iPhone 17 Pro Max running iOS 26.5.1.

### MVP2

- Add explicit listening, nearby POI discovery, longer optional descriptions, and navigation handoff.
- Example flow: RideHorizon suggests a nearby point of interest; the rider asks for more detail; RideHorizon gives a bounded description; the rider says "navigate to Caernarfon Castle"; RideHorizon hands the destination to Google Maps, Apple Maps, or another chosen navigation target.
- Keep RideHorizon separate from route planning. It may help choose or describe a destination, but the navigation app owns the route.
- Listening must start bounded and controllable as the first interactive-guide increment. It is separate from the passive guide's continuously updated geographic context.
- Longer descriptions should be explicit, interruptible, and preferably stopped-only or rider-enabled while moving.
- Begin learning preferences through simple feedback such as topics, "more like this", "less history", "shorter", and "more detail".
- Choose the first navigation app or handoff target before implementation.

### Later Versions

- Add open-ended rider questions after MVP2 validates listening and POI handoff, then expand both passive and interactive guidance while the rider chooses how much guidance they want.
- Expose custom instructions for announcement style and content preferences.
- Support different instructions by boundary type, such as town, county, region, country, landmark, or history.
- Expand from UK-only to UK and Europe.
- Add car support after the motorbike use case is validated.

Decisions:

- Default real-ride interval is `10 s`.
- Default real-ride content depth is Short Facts.
- Default repeat settings keep street off and town, county, region, and country on.
- Deterministic UK place/boundary data is deferred until after MVP1 field trial.
- MVP1 build scope stops at Location screen completion plus first-time rider polish before the 2026-07-03 field trial.

Open questions:

- How should custom instructions be constrained so rider-facing speech stays short and safe?
- Which navigation apps should MVP2 target first for POI handoff?
- Should rider voice questions be allowed while moving, stopped-only, or disabled by default?
- Which POI sources are acceptable for MVP2: pre-generated touring packs, Apple/MapKit search, Wikipedia/Wikidata, OpenStreetMap, server API, or live LLM?

## Related Local Context

Focus Planner context:

- Local folder: `/Users/rob_dev/DocsLocal/focus_planner`
- Trello export: `/Users/rob_dev/DocsLocal/focus_planner/bmWfhK1S - robs-todo.json`
- Relevant cards:
  - `#448 RideHorizon App`
  - `#449 Test cursor and Claude with RideHorizon`
  - `#455 Project (iPhone app, RideHorizon project)`

ICB catalogue context:

- Local repo: `/Users/rob_dev/DocsLocal/digital-mercenaries-ltd/icb-catalogue`
- GitHub repo: `https://github.com/rjbarbour/icb-catalogue-processing.git`
- RideHorizon ICB: `/Users/rob_dev/DocsLocal/digital-mercenaries-ltd/icb-catalogue/staged_icbs/6a1047a6a591ed37d9fd4e0e.md`

Market validation context:

- Business validation plan: `/Users/rob_dev/DocsLocal/motoguide/repo/docs/product/strategy/BUSINESS_VALIDATION_PLAN.md`
- PMF Factory / 100 Tasks review: `/Users/rob_dev/DocsLocal/motoguide/repo/docs/product/strategy/PMF_FACTORY_100_TASKS_REVIEW.md`
- Current 14-day validation sprint: `/Users/rob_dev/DocsLocal/motoguide/repo/docs/product/strategy/TWO_WEEK_MARKET_VALIDATION_PLAN.md`
- Deep-research report: `/Users/rob_dev/DocsLocal/motoguide/resources/RideHorizon_market_deep-research-report.md`
- Supporting landing-page tool: `/Users/rob_dev/DocsLocal/landing_page_tool`

Notion operating references read on 2026-07-02:

- `MacBook Python (uv-managed, 3.13 standard)`: https://app.notion.com/p/33ea4c502b178138ab92fb8d4397662e
  - Use `uv` for Python work. Prefer explicit project pins; use `uv run --python 3.13 ...` outside pinned projects.
  - Avoid bare `python3` for project setup because this Mac also has Python 3.14 and Apple system Python.
- `SOP: Secret Management in Agentic AI Development v3.0`: https://app.notion.com/p/320a4c502b1781d9ab34c4abf6d44152
  - Never persist secrets to code, docs, logs, chat, Notion, or repo files.
  - Retrieve secrets at runtime. Local development may use macOS Keychain; deployed services should use the platform secret store, with AWS Secrets Manager as the preferred canonical store for AWS-hosted work.
  - Treat credential-like strings as sensitive and do not reproduce them.
- `SOP: Diagnostic Script Standards for LLM-Assisted Debugging v1.0`: https://app.notion.com/p/324a4c502b1781298a2cc9cd702fb31b
  - Diagnostic scripts must use dual output with `tee`, visible START/DONE markers, timestamped progress, and clean `tee` teardown.
  - Default to `SANITIZE_FOR_LLM=true`; redact usernames, home paths, hostnames, IPs, emails, task content, and unrelated process arguments at collection time.
  - Collect the minimum data needed and warn before slow operations.

## Working Rules

- Treat questions, musings, and hypotheticals as read-only. Do not edit files, run tests or builds, deploy, delegate, or commit unless the user explicitly requests implementation or another state-changing action. A question asked during an active implementation task does not expand that task's scope.
- Rob is not familiar with the Xcode interface. When an Xcode action is needed, give click-by-click guidance using the control's visible label; do not assume knowledge of schemes, destinations, archives or build configurations.
- Preserve rider safety as a first-order requirement.
- Keep speech short, sparse, and interruptible.
- Prefer deterministic location logic before AI-generated content.
- Keep routing separate from place awareness.
- Add tests around location-change detection, announcement throttling, and speech text generation.
- Validate Bluetooth/audio/background behavior on the physical iPhone before calling ride-facing work done.
- The primary physical test device is an iPhone 17 Pro Max running iOS 26.5.1.
- Do not commit secrets, Trello exports, personal ride logs, location history, or private notes.

## Development Workflow

Before building, archiving, signing, uploading or diagnosing an iOS/TestFlight release, fetch and follow [SOP: iOS Build and TestFlight Deployment v1.0](https://app.notion.com/p/3b4a4c502b1781e18977d4e2d9b75c74). Treat it as the canonical operating procedure; retain this project's stricter release, safety, privacy and exact-build evidence gates.

## Adaptive agentic delivery

For planning and software delivery, fetch and follow [SOP: Adaptive Agentic Software Delivery v1.6](https://app.notion.com/p/3aea4c502b1781a888b1f8e851697813). Treat it as binding for this personal project unless an explicit project requirement conflicts.

Before substantive repository changes, fetch and follow [SOP: Tracked Work and Git Change Integration v0.6](https://app.notion.com/p/3b5a4c502b17815ea525d3c91dc65cf0). Route dirty, mixed-task or legacy state through the linked repository-hygiene procedure before normal delivery.

Backlog.md is the canonical delivery ledger. Its repository-backed records live under `backlog/` and its project configuration is `backlog.config.yml`. Before creating, claiming, executing or closing work, run `backlog instructions overview`, read the matching task guide it names, and inspect the task with `backlog task view RH-XXX --plain`. Use supported public `backlog` CLI commands for every task, document and decision mutation; do not edit generated records directly. In Backlog.md v1.50.1, `backlog decision list --plain` is the decision index and `backlog doc view doc-003 --plain` holds the complete accepted decision content because the public CLI cannot populate generated decision bodies. Keep the long-range plan shallow and revisable, with only the next one to three work items labelled `ready`. Give the active item a Goal that references its ID and evidence contract. Use independent evaluation, link evidence before **Done**, update `PROJECT.md` without duplicating ledger status, and stop at every milestone health and replenishment gate.

### Backlog.md browser runtime

- Whenever actively working on RideHorizon, ensure the Backlog.md browser is running at `http://127.0.0.1:6420`; start it without waiting for the owner to ask.
- If it is not already listening, run the exact command `backlog browser --port 6420 --no-open` immediately with host/escalated execution. Do not attempt sandbox execution first.
- Keep the server running for the active project session unless the owner asks for it to stop.

Use Plan for direction, Goal for the active work item and Loop only for bounded machine-verifiable iteration. Treat coding agents and IDEs as execution surfaces, not project trackers. Use the Delivery Risk Cube to compare the evidence shape with the project's next commitment. Record hard-to-reverse, cross-increment or surprising architectural choices in the project decision log or an ADR; do not embed them silently in code. Do not continue automatically into later milestones.

The canonical integration checkout is `/Users/rob_dev/DocsLocal/motoguide/repo`. Task worktrees may be created explicitly for claimed Backlog.md work items.

- Never let two agents edit the same worktree.
- Parallel implementation requires separate worktrees, integrated dependencies, explicit `ready` labels, limited conceptual and file overlap, and independent verification. A `parallel-candidate` label records a candidate only; the coordinator must recheck overlap against current `main` before claiming it.
- Use one work-item ID, branch, worktree and pull request per implementation task. The coordinator owns worktree creation, task coordination, model assignment, serial merge order, current-`main` verification and ready-queue replenishment. Implementation agents do not merge their own work.
- Use Codex Spark for highly constrained, surgical tasks with deterministic acceptance evidence. Use a higher-capability model when the task contains unresolved architecture, broad coupling or ambiguous failure analysis.
- Do not run multiple `xcodebuild` jobs against the same `DerivedData` path. Parallel worktrees must use distinct derived-data paths.
- Prefer writing and compiling over repeated full test/deploy cycles.

### DerivedData lifecycle

- Keep every local Xcode cache under the single external parent `/private/tmp/RideHorizonDerivedData`. Do not create `DerivedData` or `DerivedData-*` directories in the repository or its worktrees.
- `tools/derived-data path` returns a cache path derived from the current branch, so separate worktrees do not share a cache. Set `RIDEHORIZON_DERIVED_DATA_KEY` only when an explicit stable key is required.
- Run `tools/derived-data clean` from the task worktree after its final build, test, install and evidence capture, before removing the worktree. Expected result: it reports the exact task cache removed, or that no cache exists.
- Run `tools/derived-data prune 7` at milestone or repository-hygiene gates. Expected result: caches older than seven days are removed and recent caches are retained.
- Release `.xcarchive` bundles are evidence, not DerivedData. Preserve required archives in the standard Xcode archive area outside the repository before deleting build output.

### Architecture programme efficiency

For the High-priority architecture programme, `RH-013.02 — Baseline capture` owns the baseline; `RH-013.36 — Dependency foundation`, `RH-013.37 — Ride orchestration` and `RH-013.38 — Announcement orchestration` own the three execution branches, worktrees, commits and pull requests. `RH-013.01 — Settings boundary` and `RH-013.03` through `RH-013.13 — Remaining High architecture checkpoints` are acceptance checkpoints inside those batches, not separately claimable branches or pull requests.

- Every commit uses the owning batch ID. Commit bodies and evidence name the checkpoint IDs and descriptions covered.
- Checkpoints remain To Do while their batch is active. After the batch merges, the coordinator verifies and closes its checkpoint records from current `main`, then closes the batch and replenishes the ready queue.
- Run focused deterministic tests after coherent checkpoint groups, not after every edit. The focused test invocation is also the compile check.
- Run the complete iOS suite only at the baseline, ride-orchestration gate and final announcement-orchestration gate.
- Run unsigned Release builds only at the baseline and final announcement-orchestration gate.
- Run the proxy suite only at the baseline unless proxy or shared-contract files change.
- Build, install and launch on the physical iPhone once at the final High architecture gate, unless an earlier change demonstrably alters runtime platform behaviour.
- Use one sequential DerivedData path per batch. Parallel workers must use distinct paths and may return commits only after an overlap check.

This block overrides the conflicting per-task branch/commit/pull-request rule above and the more frequent build and device-deploy defaults below only for the High-priority architecture programme.

### Default loop

Batch changes, then validate once:

1. **First** capture the requested work in plan/spec docs before touching implementation. Update the relevant plan files (for example `docs/product/plans/MVP_POLISH_PLAN.md`, `docs/project/status/MILESTONE_5_STATUS.md`, `MILESTONES.md`, and any active feature spec) with the exact ask, acceptance criteria, and rationale.
2. Confirm the plan and implementation files are in sync before coding.
3. Implement a coherent chunk of work (feature slice, bugfix, or polish group).
4. Run a compile check (`xcodebuild build` for the physical device destination).
5. Deploy to the iPhone if connected (see Device Deploy).
6. Run the simulator unit test suite only at meaningful checkpoints — not after every small edit.

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

When reporting that the app was installed or updated on the iPhone, always include the installed app version and bundle version, for example `RideHorizon v0.12.2 (20260703.0258)`.

Primary device:

```text
Robert's iPhone — id 00008150-000C70883E87401C
```

Check the device is available:

```bash
xcodebuild -showdestinations -project /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj -scheme RideHorizon 2>&1 | rg "Robert's iPhone"
```

Build, install, and launch:

```bash
xcodebuild build -project /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj -scheme RideHorizon -destination 'platform=iOS,id=00008150-000C70883E87401C' -derivedDataPath "$(/Users/rob_dev/DocsLocal/motoguide/repo/tools/derived-data path)" -allowProvisioningUpdates

xcrun devicectl device install app --device 00008150-000C70883E87401C "$(/Users/rob_dev/DocsLocal/motoguide/repo/tools/derived-data path)/Build/Products/Debug-iphoneos/RideHorizon.app"

xcrun devicectl device process launch --device 00008150-000C70883E87401C ai.digitalmercenaries.ridehorizon
```

Expected result: the latest build is on the phone and the app opens.

If the phone is not connected, say so briefly and continue. Do not block the task on device deploy failure.

## Commands

Clone the GitHub project into the permanent working-copy subfolder:

```bash
git clone https://github.com/rjbarbour/MotoGuide.git /Users/rob_dev/DocsLocal/motoguide/repo
```

Expected result: `/Users/rob_dev/DocsLocal/motoguide/repo` contains `.git`, `RideHorizon.xcodeproj`, `RideHorizon/`, `RideHorizonTests/`, and `RideHorizonUITests/`.

Open the Xcode project:

```bash
open /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj
```

Expected result: Xcode opens the RideHorizon project.

Run unit tests on the simulator at a milestone or pre-commit checkpoint (not after every small change):

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/RideHorizon.xcodeproj -scheme RideHorizon -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath "$(/Users/rob_dev/DocsLocal/motoguide/repo/tools/derived-data path)" -only-testing:RideHorizonTests
```

Expected result: the RideHorizon unit test target builds and runs in the iOS Simulator.

Inspect the RideHorizon ICB:

```bash
sed -n '1,220p' /Users/rob_dev/DocsLocal/digital-mercenaries-ltd/icb-catalogue/staged_icbs/6a1047a6a591ed37d9fd4e0e.md
```

Expected result: prints the 11-section Idea Capture Brief for RideHorizon.

Search Focus Planner for RideHorizon cards:

```bash
jq -r '.cards[]? | select((.name + " " + (.desc // "")) | test("ridehorizon|moto guide"; "i")) | [.idShort, .name, .dateLastActivity] | @tsv' '/Users/rob_dev/DocsLocal/focus_planner/bmWfhK1S - robs-todo.json'
```

Expected result: prints the RideHorizon-related Trello cards.

## Documentation Rules

- Use ISO-8601 dates, for example `2026-07-01`.
- Put planning documents in the repository root unless there is a clearer existing docs structure.
- Keep milestone plans high level unless the user asks for implementation tickets.
- Record assumptions explicitly.
- When giving commands, include the exact command and expected result.

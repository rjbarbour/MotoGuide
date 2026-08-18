# RideHorizon Architecture Refactor Plan

Date: 2026-08-04

Status: Approved direction; delivery graph captured; implementation remains gated by Backlog.md readiness and dependencies.

Status authority: Backlog.md CLI task records under `../../../backlog/`

## Control-plane relationship

Verified on 2026-08-18: this document remains the canonical architectural direction for the refactor programme. It owns the rationale, target boundaries, milestone order, gates, non-goals and programme completion condition. It has not been replaced by, or copied wholesale into, the Backlog.md CLI records.

Backlog.md is the sole live delivery ledger. It owns task status, readiness, claims, execution evidence and completion:

- Milestone `m-0`, **Architecture refactor programme**, holds the programme outcome and replenishment gate.
- `RH-013` is the non-executing programme container and links every child back to this plan.
- `RH-013.01` through `RH-013.34` decompose the phases below into one-worktree, one-branch and one-pull-request increments with explicit dependencies and acceptance evidence.
- Phase and `parallel-candidate` labels describe the intended execution shape. They do not make a task ready or authorise simultaneous edits.

For immediate continuation, run `backlog instructions overview`, `backlog task view RH-013 --plain` and `backlog task list --parent RH-013 --plain`. Only children explicitly labelled `ready`, with every dependency integrated, may be claimed. The long-range child graph remains revisable at phase health gates even though its current outcomes and dependencies are recorded. If the CLI and this document disagree about live status, the CLI wins; if they disagree about architectural direction, stop and reconcile the plan and task contract explicitly.

## Integration checkpoint — 2026-08-18

The user authorised integration of the completed planning batch by replying `Proceed.` No integration command had run at the checkpoint captured here, and refactor implementation had not started.

Verified local state:

- Checkout: `/Users/rob_dev/DocsLocal/motoguide/repo`.
- Branch: `main`.
- The planning batch is local and uncommitted. It includes milestone `m-0`, programme updates to `RH-013`, the shaped child graph `RH-013.01` through `RH-013.34`, the parallel-worktree rules in `AGENTS.md` and this plan's control-plane reconciliation.
- The child graph was checked as 34 children, all under `RH-013` and milestone `m-0`, with plan references, at least three acceptance criteria per child, no unknown dependencies, no dependency cycles and no premature `ready` label.
- Eleven tasks carry the `parallel-candidate` label: `RH-013.04`, `RH-013.05`, `RH-013.16`, `RH-013.17`, `RH-013.20`, `RH-013.23`, `RH-013.25`, `RH-013.26`, `RH-013.29`, `RH-013.30` and `RH-013.31`. Candidate status is not execution authority; overlap must be rechecked against current `main` before claiming.
- `RH-013.34` remains a human evidence gate because changing production location defaults requires physical ride and battery evidence.
- `git diff --check` passed at this checkpoint. No application tests were run because only delivery records and documentation changed.

Immediate continuation:

1. Refresh the binding delivery and Git-integration SOPs, then run `backlog instructions overview` and read the task guide it names. Expected result: the current supported workflow for creating and integrating a control-plane task is displayed.
2. Create one tracked control-plane work item for integrating this planning batch, using supported public `backlog` CLI commands only. Expected result: one task owns the Goal, branch, worktree, commit, pull request and integration evidence for these existing changes.
3. Isolate the planning diff on that task's branch/worktree without losing or mixing the current local changes. Expected result: the integration checkout and task checkout have explicit, recoverable ownership.
4. Verify the exact file set, child graph and `git diff --check`; commit, push, open one pull request, review it independently and merge it serially under the coordinator's control. Expected result: the planning batch is present on current `main` through one traceable pull request.
5. Verify merged `main`, close the control-plane task through the CLI, remove its worktree and branch as the applicable SOP directs, then make `RH-013.02` the first `ready` child. Expected result: `main` is checkpoint-clean and `RH-013.02` is ready to capture the clean architecture-refactor baseline.
6. Stop. Do not begin `RH-013.02` or any refactor implementation in the planning-batch integration turn.

## Bottom line

Refactor through small, behaviour-preserving milestones. Establish the iOS dependency boundaries first, then make the app–proxy contract executable, simplify the proxy behind that contract, and only then tighten diagnostics and Swift concurrency.

Keep the existing iOS application target and proxy deployment. Source-level boundaries and narrow interfaces are sufficient at this stage; separate Swift packages, services or deployments would add cost without solving the present problems.

The first execution sequence is RH-013.02 to establish the clean baseline, followed by RH-013.01 (legacy RH-013A) only after that dependency is integrated. Capturing the full task graph does not make later increments implementation-ready.

## Why this work is needed

The product behaviour is well tested, but several central types carry too many responsibilities:

- `LocationManager` coordinates location, geocoding, ride lifecycle, boundary detection, fact retrieval, speech, audio, settings and diagnostics.
- `ContentView` constructs concrete dependencies while also coordinating feature and application operations.
- The iOS client retains only the proxy token and ignores session expiry and fallback metadata.
- `JdbcSessionAuthority` combines authentication, session issuance, quotas, installation administration, database compatibility and future attestation concerns.
- Diagnostics and speech lifecycle APIs use long optional-parameter or callback lists rather than explicit events.

These concentrations make safe changes slower because a local feature change can affect lifecycle, persistence, network and audio behaviour at once.

## Architectural direction

Dependencies should point inwards from platform adapters and views towards small application and domain interfaces:

```text
SwiftUI features
    -> application coordinators
        -> domain policies and state machines
        -> service interfaces
            -> Apple, network and persistence adapters

HTTP controllers and filters
    -> proxy application services
        -> session and quota policies
        -> repository interfaces
            -> JDBC/PostgreSQL adapters
```

Shared services should describe capabilities, not features:

- `LocationSource`
- `PlaceResolver`
- `FactClient`
- `ProxySessionProvider`
- `SpeechOutput`
- `RideSettingsStore`
- `DiagnosticsSink`

Feature/application types should own use-case sequencing:

- ride session
- announcement coordination
- Location screen presentation
- Settings
- onboarding and AI consent
- speech calibration
- test route

Rules for every milestone:

1. Preserve observable behaviour unless the backlog contract explicitly authorises a change.
2. Add or strengthen tests at the interface being introduced; do not test private implementation details.
3. Prefer immutable value snapshots and explicit events over shared mutable state and optional parameter bags.
4. Inject time, scheduling, location, geocoding, persistence and network edges where deterministic tests need control.
5. Keep adapters concrete at the composition root and protocols narrow at their consumers.
6. Do not create a protocol for every type, split files solely by line count or introduce a general-purpose framework.
7. Each increment must be independently reviewable and releasable.

## Milestone sequence

### Milestone 0 — Establish the refactor baseline

Outcome: begin from a clean, known release baseline and prevent accidental behaviour changes.

Work:

- Finish or deliberately pause the current RH-001/RH-003/RH-004 gate.
- Rebase or branch from clean `main` after the accepted work is committed.
- Record the complete iOS and proxy test baseline.
- Treat the existing lifecycle, announcement, audio and persistence behaviour as characterisation unless a later work item changes it explicitly.

Gate: clean working tree; branch based on current `main`; iOS unit suite, unsigned Release build and proxy test suite pass. Stop if the baseline is red.

### Milestone 1 — Create the iOS dependency foundation

Outcome: settings and dependency construction no longer leak across views and the central runtime object.

Order:

1. RH-013.01 (legacy RH-013A): introduce a typed `RideSettings` snapshot, a narrow `RideSettingsStore` and the existing `UserDefaults` adapter.
2. Move concrete app dependency construction to the `RideHorizonApp` composition root.
3. Pass feature dependencies explicitly; keep SwiftUI presentation state within feature models or views.

Boundaries:

- Preserve all existing `UserDefaults` keys, defaults and migration behaviour.
- Do not redesign the Settings UI; RH-005 remains a separate product increment.
- Do not add packages, a dependency-injection framework or a service locator.

Gate: no ride-setting reads or writes outside the settings adapter and composition root; clean-install and existing-install settings tests pass; the full iOS suite and unsigned Release build pass.

### Milestone 2 — Extract ride-session orchestration

Outcome: the ride use case owns start, accepted location processing, inactivity and end cleanup without owning Apple framework details.

Work:

- Introduce narrow `LocationSource`, `PlaceResolver`, clock/scheduler and notification edges.
- Move use-case sequencing into `RideSessionController` while retaining the existing pure `RideSessionLifecycle` policy.
- Keep Core Location configuration and callbacks in the platform adapter.
- Split the monolithic test suite into contract, lifecycle and adapter-focused suites as ownership moves.

Gate: start/end/inactivity, stale callback rejection, cancellation and test-route behaviour are proven with deterministic fakes; existing physical-device release evidence remains valid or is repeated where the seam changed.

### Milestone 3 — Extract announcement coordination

Outcome: boundary acceptance, fact retrieval, speech selection, audio ownership, cancellation and supersession form one explicit application workflow.

Work:

- Introduce consumer-owned `FactClient`, `SpeechOutput` and `DiagnosticsSink` interfaces.
- Move sequencing into `AnnouncementCoordinator`.
- Retain pure announcement policy and queue types for prioritisation and suppression.
- Make cancellation and terminal cleanup explicit results, not incidental callback combinations.

Gate: fact, Names Only, Apple Voice, Premium Voice, retry/fallback, interruption, supersession and End ride paths are deterministic; RH-004 audio behaviour and privacy-safe diagnostics remain unchanged.

### Milestone 4 — Make the app–proxy contract executable

Outcome: client and proxy agree on sessions, errors and payloads through tests rather than parallel documentary descriptions.

Work:

- Model a typed `ProxySession` containing token, expiry and fallback state.
- Refresh proactively before expiry while retaining bounded 401 invalidation and reprovisioning.
- Make `FACT_PROXY_OPENAPI.yaml` the machine-checked contract and align its version references.
- Add shared golden request, response and error fixtures consumed by Swift and Java tests.
- Standardise the error envelope, request identifier and retry classification, including `Retry-After` where applicable.
- Add server response-schema validation or equivalent contract tests. Do not adopt full client/server code generation in this milestone.

Gate: expiry and clock-skew tests pass; every published operation and error shape has app and proxy evidence; the OpenAPI validation command fails on drift.

### Milestone 5 — Decompose proxy authentication and persistence

Outcome: live authentication, quota and persistence responsibilities can evolve independently.

Work:

- Keep `SessionAuthority` restricted to the capabilities used by live request paths.
- Extract quota accounting into `QuotaLedger` and database access into focused repositories.
- Isolate operator administration and future App Attest behind separate authorities.
- Split the large configuration bag into validated configuration groups.
- Add PostgreSQL integration tests for Flyway migrations, authentication and quota atomicity/concurrency; retain H2 only for tests that do not claim PostgreSQL behaviour.

Gate: controller/filter behaviour is unchanged; PostgreSQL integration tests prove migrations and concurrent quota decisions; no dormant attestation operation is exposed as live capability.

### Milestone 6 — Replace callback and diagnostic parameter bags with events

Outcome: speech and diagnostics have explicit, exhaustively handled lifecycle events.

Work:

- Define typed speech lifecycle events and typed diagnostic payloads.
- Keep privacy filtering at the diagnostic boundary.
- Migrate one producer/consumer path at a time and remove compatibility shims after the full suite passes.

Gate: the compiler identifies unhandled lifecycle cases; no event can carry prohibited location, content or credential data; export retention behaviour remains unchanged.

### Milestone 7 — Tighten platform correctness

Outcome: concurrency and Core Location policy are explicit and evidence-led.

Work:

- Enable complete Swift concurrency checking as warnings and resolve findings by ownership, isolation and value semantics.
- Consider Swift 6 language mode only after the warning baseline is clean.
- Encapsulate accuracy, activity type, distance filtering and automatic pausing in a typed location policy.
- Compare policy variants through deterministic tests and physical ride/battery evidence before changing production defaults.

Gate: complete concurrency checking is clean; no unchecked sendability is added merely to silence warnings; any location-policy change has physical evidence and a rollback point.

## First unattended execution sequence

RH-013.02 establishes the exact clean baseline and stops if any declared gate is red. After RH-013.02 is integrated and the coordinator marks RH-013.01 ready, RH-013.01 is the first implementation increment. Inspect each delivery contract with `backlog task view RH-013.02 --plain` and `backlog task view RH-013.01 --plain` before claiming it.

Suggested commit sequence:

1. Add characterisation tests for current setting keys, defaults and round trips.
2. Add `RideSettings`, `RideSettingsStore` and the `UserDefaults` adapter without changing consumers.
3. Migrate one coherent consumer group at a time to the store.
4. Remove only the duplicated direct access made obsolete by the migration.
5. Run the complete gate and obtain an independent diff review.

Each implementation agent must stop at its child-task boundary, report evidence and leave later tasks unstarted. A failed test, required key migration, observable settings change, unrelated release-candidate conflict or need for a new framework is a stop condition rather than permission to widen scope. The coordinator may replenish the ready queue only after integration, current-main verification and the applicable phase health gate.

## Verification baseline

From the repository root:

- iOS tests: `xcodebuild test -project RideHorizon.xcodeproj -scheme RideHorizon -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath DerivedData-ArchitectureRefactor -only-testing:RideHorizonTests` — expected result: `** TEST SUCCEEDED **` with zero failures.
- unsigned iOS Release build: `xcodebuild build -project RideHorizon.xcodeproj -scheme RideHorizon -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData-ArchitectureRefactor-Release CODE_SIGNING_ALLOWED=NO` — expected result: `** BUILD SUCCEEDED **`.
- proxy tests, when proxy code or contract fixtures change: `cd fact-proxy && ./gradlew test --no-daemon` — expected result: `BUILD SUCCESSFUL`.
- current documentary OpenAPI parse, until Milestone 4 replaces it with executable validation: `ruby -e 'require "yaml"; doc = YAML.load_file("FACT_PROXY_OPENAPI.yaml"); abort "missing openapi" unless doc["openapi"] == "3.0.3"; abort "missing /v1/fact" unless doc.dig("paths", "/v1/fact", "post"); abort "missing FactRequest" unless doc.dig("components", "schemas", "FactRequest"); puts "OpenAPI YAML parsed: #{doc["info"]["title"]} #{doc["info"]["version"]}"'` — expected result starts with `OpenAPI YAML parsed:`.

If the named simulator runtime is unavailable, stop and record the available destination rather than silently substituting a weaker build-only check.

## Decisions and non-goals

- Use source-level ownership before module extraction. Reconsider Swift packages only when independent build boundaries or reuse justify them.
- Keep one proxy deployment. This refactor separates responsibilities inside it; it is not a microservices programme.
- Preserve the public API during the first three milestones.
- Keep visual Settings redesign, onboarding polish, caching, route prefetch, iPad support and new product functionality in their existing backlog items.
- Do not combine refactoring with provider changes, audio-profile promotion, App Attest enforcement or database migration unless its milestone explicitly requires it.
- Create an ADR only if implementation reveals a hard-to-reverse boundary choice not already settled here, such as a new module/deployment boundary or a changed public contract.

## Completion condition

The programme is complete when feature behaviour is coordinated by small application types, platform and persistence details sit behind consumer-owned interfaces, app–proxy drift is caught automatically, proxy session/quota behaviour is proven on PostgreSQL, and strict concurrency checking passes without weakening safety.

Success is not measured by file count or line count. It is measured by whether a feature can be changed through one clear use-case boundary with deterministic tests and without reaching through unrelated services.

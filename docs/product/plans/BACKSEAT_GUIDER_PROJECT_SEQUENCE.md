# Family Passenger Product Delivery Sequence

Date: 2026-08-11

Reconciled: 2026-08-17

Status: **Reconciled delivery map; sequencing proposal, not an implementation authorisation or detailed ticket plan**

## Purpose

This document preserves the outcome of the 2026-08-10 to 2026-08-11 planning session and provides a practical order for splitting RideHorizon into a product family. It coordinates existing work without expanding every idea into a ticket.

The two app products are:

- **RideHorizon** — the existing motorcyclist geographic-awareness app.
- **Family passenger app** — a separate passenger experience whose provisional working name is **Backseat Guider**. The name is AMBER pending solicitor-led clearance and is not adopted by this plan. Do not use “Family Guide” as the product name.

“Product family” is the umbrella term. “App product” distinguishes the two deliverables. Avoid “version”, because neither product supersedes the other.

## How to use this document

- Use it as the coordination map for the product-family transition, not as the live work ledger.
- Keep the durable decisions and workstream boundaries stable; update repository evidence and unresolved gates when their source work changes.
- The product-design session should consume the audience, interaction and pronunciation decisions without inheriting the delivery sequence as product authority.
- The architecture session should consume the desired technical end state and verify or revise its proposed seams against the cleaned-up codebase.
- Derive only the next phase and the smallest following experiment into ready work items in `ITEM-BACKLOG.md`. Do not create the complete future programme in advance.
- Review the phase exit evidence before advancing. A phase heading is not itself a sprint commitment.

## Authority and boundaries

- The integrated [Family Journey Product Framework](../reference/FAMILY_JOURNEY_PRODUCT_FRAMEWORK.md) is inspirational product context, not delivery authority. Do not convert it wholesale into work items.
- The family-trip priority overlay was integrated through PR 9 and now lives in `ITEM-BACKLOG.md`. It supplies priorities, not a technical product split or implementation authorisation.
- `ITEM-BACKLOG.md` is the sole live delivery ledger. Do not restore deprecated `Backlog.md`, introduce product-specific ledgers or improvise a new schema in this plan.
- Keep parental controls and a parent experience out of the current implementation slice. Existing ideas may remain in the item backlog.
- The landing-page demand test is a separate project and delivery stream. Coordinate learning and dependencies, but do not absorb its implementation into the app plan.
- Do not start the broad architecture refactor merely to enable the first controlled family test. Capture the desired seams so the separate architecture review can account for them.

## Durable product decisions

### Decision KD-01 — Product and device shape

The family passenger app is a separate app product, not a runtime “kids mode” and not a Debug/Release-style build configuration. The target end state is one repository and probably one Xcode project containing separate app targets which consume shared modules.

The initial family-passenger device is iPad. Preserve the option for both app products to support iPhone and iPad later; do not encode product identity as device identity.

Each app product will require its own bundle identifier, app icon, entitlements and permissions, product configuration, signing/provisioning, archive and App Store Connect record. The same Apple developer account and TestFlight service can manage both records, but builds and tester assignments remain product-specific.

### Decision KD-02 — Audience boundary

Treat the declared product audience as **13+** for the current plan. Do not represent the family passenger app as an Apple Kids Category app without a separate product, privacy and compliance decision.

An intended controlled tester is under 13. Consent and a small internal cohort do not by themselves resolve platform, privacy or child-data obligations. Do not hide an under-13 path in prompts or opaque configuration. Before that tester uses voice transcripts, location-bearing requests or server logging, complete an explicit data-flow and compliance gate and record the permitted test arrangement. This is an unresolved release/test constraint, not an implementation detail.

### Decision KD-03 — Initial question interaction

Use explicit, bounded interaction rather than always-on listening:

1. Tap to begin microphone capture.
2. Tap to stop capture and transcribe.
3. Review the transcript.
4. Tap to submit.

An iOS keyboard input is an acceptable tactical fallback. Proper low-latency conversational voice is being researched separately and must not block this slice.

### Decision KD-04 — Data boundary and diagnostics

- Raw voice must stay on the device.
- Enforce that boundary technically: require on-device recognition and check that the selected recogniser supports it. If it does not, disable microphone transcription and offer typed keyboard input; do not silently fall back to network speech recognition.
- The transcript necessarily leaves the device when submitted to the current remote answer service and may contain location context.
- Server-side transcript logging was proposed tactically but is **not approved for the under-13 test** until the data/compliance gate above defines purpose, access, retention and deletion.
- The existing device diagnostic log remains on the device. Keep copy/export as the only collection mechanism for now; do not add an automatic collection endpoint, email action or WhatsApp action in this slice.

### Decision KD-06 — Place naming and pronunciation

Tactically prefer a conventional English exonym, pronounced naturally by a knowledgeable British-English speaker. Fall back to a chosen local name when there is no appropriate English exonym.

This is not equivalent to requesting a native accent. The intended quality is a recognisable, respectful place-name pronunciation embedded naturally in British-English narration, without exaggerated accent switching.

Multilingual places may have several local names as well as an English name. Before implementation, work through a small scenario set covering at least:

- an English exonym distinct from the local endonym;
- one name shared across English and the local language but pronounced differently;
- a multilingual place with several official local names, such as a Swiss case;
- no established English exonym; and
- a TTS provider unable to pronounce the selected display name acceptably.

For each scenario, distinguish source names, selected display name, spoken form, pronunciation representation, language context and fallback. The scenario exercise is future shaping work, not part of the initial feature capture.

### Decision KD-07 — Deployment identity evidence

With more than one test device, build identity must be visible and reportable per installation.

For a named TestFlight tester, App Store Connect’s **TestFlight → Testers → All** view can show Installed status, device model, OS and platform. It shows only the most recently updated device when that tester has installed on several devices, and tester metrics can take up to 24 hours to appear. Its app-version field is the most recent build the tester can access, so it is not sufficient proof of the exact build currently running on every device. Build-level TestFlight metrics provide aggregate install counts rather than a complete live device inventory.

Direct Xcode or other non-TestFlight installations do not appear in TestFlight records. For those builds, use local diagnostic evidence.

Before adding phone-home telemetry, first use a local About/Diagnostics surface that exposes app product, semantic version, build number, bundle identifier, device model and OS version and can be copied with the existing diagnostic export. Any remote installation telemetry requires a separate privacy and retention decision.

### Current installation and usage evidence boundary

Verified from the repository on 2026-08-11:

- **App Store Connect/TestFlight:** for a named TestFlight tester, App Store Connect can record Installed status, platform, device model and OS. When one tester uses several devices, the tester view exposes only the most recently updated device, and its app-version field identifies the newest build available to that tester rather than proving the exact build installed on every device. Build metrics are aggregate. Direct Xcode installations are absent. This is useful supporting evidence, not a complete installation inventory.
- **RideHorizon proxy database:** `fact-proxy/src/main/resources/db/migration/V2__session_access.sql` stores a pseudonymous installation UUID and key ID, App Attest environment, status, creation/last-seen/revocation timestamps, assertion state, sessions and daily fact/speech usage counts. It has no app version, build number, device model, OS version or human tester identity columns.
- **RideHorizon proxy logs:** `RequestInstrumentationFilter.java` logs a random request ID, HTTP method, route, status and duration for fact requests. Optional diagnostics in `FactController.java` add boundary/fact-mode and length metadata. The application logs do not record app version, build, device model or OS version.
- **Current conclusion:** the proxy can show that a pseudonymous installation was active and how much fact/speech capacity it used, subject to deployment and retention verification. It cannot answer which app version or device model made a request. App Store Connect provides some TestFlight device evidence but cannot prove a complete exact-build-per-device history.

Do not infer device model or exact build from the proxy's installation identifier, request `User-Agent`, App Attest environment or timestamps. If per-installation remote reporting becomes necessary, treat it as a new telemetry schema and privacy/retention decision. The current preferred evidence remains the app's local version/build display plus a privacy-safe diagnostic export from the named device.

## Desired technical end state

The architecture review should create seams corresponding to these responsibilities:

```text
RideHorizon app target ─────────┐
                                ├─ shared location and journey capabilities
Family passenger app target ────┘
            │
            ├─ product-specific experience policy and prompts
            ├─ product-specific UI, permissions and configuration
            └─ shared proxy contracts with explicit product policy at the boundary
```

The shared layer may contain location acquisition, geographic hierarchy, journey state, announcement primitives, TTS interfaces, diagnostics primitives and proxy clients. Product-specific policy must own cadence, candidate selection, safety constraints, interaction depth, prompt composition and presentation.

Do not create a “shared platform” item or module speculatively. Extract a shared capability only when both products need it and its contract is understood. Keep dependencies visible in the project control plane: app products depend on shared modules and may independently depend on the fact/speech proxy.

Configuration must be typed and testable. Do not scatter product checks such as `if kidsMode` through shared code, and do not use build configurations to express product identity.

## Workstream map

- **Workstream WS-01 — RideHorizon field defects:** Diagnose and close defects found during motorcycle road testing. Preserve the existing rider release/safety gates.
- **Workstream WS-02 — iPad defects:** Reproduce the Short Facts/Long Facts selection failure and other iPad-specific layout, background-audio and device issues. Separate genuine platform defects from family-passenger-only design changes.
- **Workstream WS-03 — Minimum passenger experiment:** Deliver only the bounded mixed-age passenger experience needed to learn from the controlled journey: profile/context, explicit transcript interaction, suitable prompts and core output.
- **Workstream WS-04 — Pronunciation and name selection:** Shape the scenario model, build a small European test corpus and establish human acceptance evidence before committing to a provider-specific pronunciation mechanism.
- **Workstream WS-05 — Product-family architecture:** Feed the desired seams above into the independent software architecture review; then make the smallest refactor needed for separate app targets and shared modules.
- **Workstream WS-06 — Build, signing and TestFlight:** Establish distinct product identifiers, schemes/targets, archives, App Store Connect records and exact-build evidence. Keep device/build identity reportable.
- **Workstream WS-07 — Product-specific documentation:** Reconcile README, architecture, operations, testing and product docs so scope and instructions identify the relevant app product without duplicating shared rules.
- **Workstream WS-08 — Validation:** Run comparative family field observation and coordinate with the separate landing-page demand experiment. Product usability evidence and market-demand evidence answer different questions.
- **Workstream WS-09 — Control-plane maintenance:** Keep `AGENTS.md`, README/PROJECT, status documents and `ITEM-BACKLOG.md` aligned as product-family work becomes active. Do not create separate product ledgers merely because there are two app products.

## Recommended sequence

### Phase PH-01 — Reconcile in-flight work and establish a safe baseline — complete

1. `ITEM-BACKLOG.md` became the sole canonical ledger through RH-044.
2. The family product framework was integrated as an inspirational reference without converting it wholesale into work items.
3. The PR 9 family-trip priority overlay was reconciled into the canonical ledger without restoring deprecated `Backlog.md`.
4. The mixed RH-045 state was checkpointed and its independent streams are being adjudicated through RH-050.
5. Build-specific road-test and iPad defects remain evidence gates for any passenger experiment; do not infer them from old checkout state.

Exit evidence: one authoritative ledger, integrated framework and priorities, a preserved source shelf, and independently reachable retained streams. Exact physical-device/build evidence remains a prerequisite for feature work, not a reason to keep PH-01 open.

### Phase PH-02 — Prove the minimum experience without premature extraction

1. Fix only the iPad defects that block the controlled passenger experiment.
2. Implement the bounded tap/transcribe/review/submit interaction with keyboard fallback.
3. Add the minimum family-passenger experience policy and mixed-age prompt/context needed for the test.
4. Keep diagnostics device-local and complete the under-13 data/compliance gate before any such testing.
5. Run the name/pronunciation scenario exercise in parallel as shaping; implement only the narrowest pronunciation improvement supported by evidence.

Exit evidence: a physical-iPad smoke test, explicit build identity, bounded interaction verified end to end, documented data flow, and a human-reviewed pronunciation sample set.

### Phase PH-03 — Create the durable product split

1. Complete the independent architecture review using this plan’s desired seams as an input.
2. Introduce separate app targets and typed product configuration.
3. Extract only the shared capabilities proven by the first experiment.
4. Add target-specific unit/build checks and archive both products independently.
5. Reconcile product-family documentation and operational runbooks.

Exit evidence: both app products build independently, shared contracts have tests, target-specific resources and permissions are correct, and no runtime mode switch defines product identity.

### Phase PH-04 — Validate before broadening

1. Run the controlled family journey and competitor comparison with concise observation evidence.
2. Run the separate landing-page demand smoke test.
3. Review failures, engagement, pronunciation, question usefulness, silence/cadence and whether the teenager finds the experience childish.
4. Decide whether to deepen the family passenger product, revisit audience/compliance, or return effort to RideHorizon defects and release work.

Stop before expanding parental features, durable child profiles, multi-device sessions, quizzes/curriculum, broad POI discovery or always-on/continuous voice.

## Reconciled repository evidence

Verified on 2026-08-17:

- `ITEM-BACKLOG.md` is the sole live delivery ledger; RH-044 completed the migration.
- PR 9's family-trip priority overlay is integrated in that ledger, including RH-046 and RH-047.
- `docs/product/reference/FAMILY_JOURNEY_PRODUCT_FRAMEWORK.md` is integrated on `main` as inspirational product context.
- RH-050 owns the remaining RH-045 source-shelf adjudication. This document and the dated name screen are the only retained ST-05 paths.
- This plan does not authorise app targets, signing, App Store Connect records, feature implementation or child-data processing.

## Immediate continuation

The next product session should not start by writing detailed tickets. It should:

1. Decide whether the family passenger experiment should take priority over current RideHorizon work.
2. If yes, inventory concrete RideHorizon road-test defects and iPad blockers against exact app builds/devices.
3. Complete the under-13 data/compliance gate before planning transcript logging or involving an under-13 tester.
4. Convert only the smallest PH-02 experiment into one or more ready `ITEM-BACKLOG.md` items.
5. Keep **Backseat Guider** provisional unless the separate name-clearance gate is passed.

Detailed target creation, refactoring and TestFlight operations must follow the canonical iOS deployment SOP at execution time.

## Research references

- [Family Journey Product Framework](../reference/FAMILY_JOURNEY_PRODUCT_FRAMEWORK.md) — inspirational context only
- [Preliminary Backseat name-availability and IP screen](../../research/2026-08-10-backseat-name-availability-ip-screen.md) — dated evidence; not legal clearance
- [Apple: add a new App Store Connect app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
- [Apple: view and manage TestFlight tester information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-and-manage-tester-information/)
- [Apple: TestFlight tester information fields](https://developer.apple.com/help/app-store-connect/reference/testflight/testflight-tester-information)
- [Apple: TestFlight build status and metrics](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-build-status-and-metrics)
- [Apple: require on-device speech recognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

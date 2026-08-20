# RideHorizon Test System

Status: Active from 2026-08-05.

This directory is the durable test-management system for RideHorizon. It explains the quality risks that matter, the evidence expected for each, and how release decisions are made. It does not replace source code tests or duplicate live execution results.

## Use this system

| Need | Authoritative record |
| --- | --- |
| Understand the product, current commitment and release gate | [`../../AGENTS.md`](../../AGENTS.md), [`../../PROJECT.md`](../../PROJECT.md) and the Backlog.md CLI (`backlog task list --plain`) |
| Select proportionate test evidence for an increment | [Test strategy](TEST_STRATEGY.md) |
| Apply test principles, result definitions, defect severity and risk acceptance | [Test policy](TEST_POLICY.md) |
| Design coverage, find gaps or choose the correct test level | [Quality-risk coverage model](QUALITY_RISK_COVERAGE_MODEL.md) |
| Analyse Calimoto GPX traces, simulate route transitions or assess route-wide content | [Simulated ride and content-assurance plan](SIMULATED_RIDE_AND_CONTENT_ASSURANCE.md) |
| Decide whether a candidate may move to the next test or release stage | [Release quality gates](RELEASE_QUALITY_GATES.md) |
| Record the current TestFlight run, stationary checks and field evidence | [`../operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md`](../operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md) |
| Run exact-build stationary RideHorizon checks, separating phone-only and X-COM2 evidence | [Stationary physical-test protocol](STATIONARY_PHYSICAL_TEST_PROTOCOL.md) |
| Configure the primary iPhone/X-COM2 test path and stopped feedback Shortcut | [`../operations/headsets/XCOM2_IPHONE_SETUP_AND_STATIONARY_TEST.md`](../operations/headsets/XCOM2_IPHONE_SETUP_AND_STATIONARY_TEST.md) |
| Run the moving-motorbike owner acceptance test | [`../operations/testflight/RIDE_UAT_PROTOCOL.md`](../operations/testflight/RIDE_UAT_PROTOCOL.md) |
| Design and execute audio coexistence checks | [`../architecture/plans/AUDIO_INTEROPERABILITY_VALIDATION_PLAN.md`](../architecture/plans/AUDIO_INTEROPERABILITY_VALIDATION_PLAN.md) |
| Assess speech intelligibility calibration | [`../architecture/specs/SPEECH_INTELLIGIBILITY_CALIBRATION_SPEC.md`](../architecture/specs/SPEECH_INTELLIGIBILITY_CALIBRATION_SPEC.md) |
| Check proxy/API behaviour and data boundaries | [`../architecture/contracts/FACT_PROXY_CONTRACT.md`](../architecture/contracts/FACT_PROXY_CONTRACT.md) and [`../../FACT_PROXY_OPENAPI.yaml`](../../FACT_PROXY_OPENAPI.yaml) |
| Assess privacy | [`../operations/privacy/PRIVACY_AUDIT_2026-07-18.md`](../operations/privacy/PRIVACY_AUDIT_2026-07-18.md) |

## Rules of use

- Backlog.md CLI records under `../../backlog/` remain the only delivery-status authority. A test result may create or close evidence for a work item; it does not independently change delivery status.
- Use `./tools/test-changed --base origin/main` for proportionate local automated tests before a PR. It compares committed, staged, unstaged and non-ignored untracked changes, reports the selected suites, then runs iOS tests for app/Xcode changes, fact-proxy tests for proxy changes, both for shared, workflow, tool or unclassified changes, and neither for documentation-only changes. Use `./tools/test-changed --all` when full automated coverage is required. The iOS suite defaults to the CI simulator destination; to run it on a connected iPhone, set `IOS_TEST_DESTINATION` to the Xcode device destination, for example `IOS_TEST_DESTINATION='platform=iOS,id=DEVICE_ID' ./tools/test-changed --file RideHorizon/ContentView.swift`. This selector does not replace physical-device, TestFlight, release or rider-safety evidence.
- Keep local Xcode output under `/private/tmp/RideHorizonDerivedData`. `./tools/derived-data path` resolves the current branch's isolated cache, `./tools/derived-data clean` removes it at task completion, and `./tools/derived-data prune 7` removes abandoned caches older than seven days. Do not create `DerivedData*` directories in the repository root.
- The High-priority architecture programme uses the tighter default budget in `../architecture/plans/ARCHITECTURE_REFACTOR_PLAN.md`: focused evidence within each batch; complete iOS suites only at baseline, ride-orchestration and final announcement gates; unsigned Release builds only at baseline and final; one proxy baseline; and one final physical iPhone build/install. Do not invoke `test-changed` merely to repeat an already recorded phase gate; risk-triggered exceptions must be recorded.
- `TESTFLIGHT_FIELD_TEST_EVIDENCE.md` remains the run record and TestFlight coverage matrix. Put observed results, build identities and retained evidence there, not here.
- Test work is evidence-led. A passing automated test does not prove real Bluetooth, background-location, perceived loudness, rider distraction or live-provider behaviour.
- Preserve privacy: do not commit personal ride routes, precise coordinates, raw diagnostics, credentials, generated speech audio, or tester identifiers beyond the minimum necessary run reference.
- Review this system at each release/milestone health gate, after a safety-relevant defect, or when product scope changes materially.

## Current focus

The current commitment is a private external TestFlight beta. The next gate is exact-build confirmation and physical evidence for the candidate selected in `../operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md`. That record currently identifies `0.12.4 (20260806.221234)` from a locally verified receipt. Do not recreate a second release checklist here or transfer results from an earlier build.

## Document control

| Role | Accountability |
| --- | --- |
| Product owner / release decision-maker | Accepts residual risk and makes the explicit release decision. |
| Test manager | Maintains this system, challenges insufficient evidence and reports risk honestly. |
| Implementer | Supplies focused automated evidence and fixes defects; is not the sole completion judge. |
| Independent reviewer | Checks the change and evidence against the intended risk controls. |
| Rider tester | Performs only safe, parked or pre-agreed field actions; gives perceptual and contextual evidence that automation cannot supply. |

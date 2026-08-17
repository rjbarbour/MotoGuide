# RideHorizon Test Strategy

Date: 2026-08-05
Status: Active. Review at each milestone health gate.

## 1. Purpose

RideHorizon is a geographic-awareness companion used beside navigation on a moving motorbike. Its most serious failures are not ordinary screen defects: distracting or stale speech, interference with navigation or music, unbounded background work, unsafe privacy handling, and an apparent but unreliable location context.

The strategy is therefore to produce decision-grade evidence at the lowest sensible test level, then prove the remaining real-world risks on the physical iPhone and helmet headset. It supports a **Build** commitment today and must be hardened before any broader public release.

## 2. Test objectives

Before a release candidate moves forward, establish proportionate evidence that it:

1. keeps the rider in control and does not require interaction while moving;
2. provides plausible, timely and non-stale place awareness;
3. speaks sparsely, intelligibly and without unacceptable interference with other audio;
4. starts and ends background location, network and audio work only within an explicit ride session;
5. degrades safely when location, geocoding, network, proxy, fact or TTS services fail;
6. protects location, rider context, diagnostics and provider credentials;
7. works on the supported iPhone/iOS and Bluetooth configuration; and
8. is releasable with a traceable build, suitable privacy/App Store evidence and an explicit residual-risk decision.

## 3. Scope and assumptions

### In scope now

- iOS onboarding, permission/consent, settings, active ride lifecycle, live location, reverse geocoding, map presentation, announcement policy and history/diagnostics;
- Apple Voice and proxy-backed facts/Premium Voice, including failure, cancellation, retry, fallback and supersession behaviour;
- the RideHorizon fact proxy, its OpenAPI contract, session provision, validation, limits, privacy retention and upstream failure handling;
- the public privacy/support site where it forms part of the app or review journey;
- physical iPhone, Bluetooth headset, music, navigation, screen-lock, background, mobile-data, battery and thermal behaviour; and
- generated-fact safety, factual plausibility, relevance, repetition and rider appropriateness.

### Deliberate limits

The current private beta is iPhone-only, UK-first, and a companion rather than a routing product. It does not claim universal compatibility with all phones, headsets, music apps, navigation apps, countries, geocoders or mobile networks. A negative result in an untested configuration is unknown, not a pass.

## 4. Risk-based approach

Every increment begins with a brief quality-risk assessment. Rate impact first, then likelihood and detectability. The resulting priority selects the evidence, rather than the implementation technology or the team’s preferred test type.

| Priority | Meaning | Minimum response |
| --- | --- | --- |
| **P0 — safety, privacy, security or release blocker** | Could distract a rider, expose sensitive data/credentials, cause unbounded background activity, block essential use, or invalidate release compliance. | Deterministic tests where possible, an independent review, targeted physical/service evidence, and no release while unresolved or unaccepted by the product owner. |
| **P1 — core journey or trust** | Breaks location awareness, correct speech, ride lifecycle, core integration or the stated beta experience. | Automated regression evidence plus the appropriate integration, device or field evidence before release. |
| **P2 — material usability or resilience** | Harms comprehension, efficiency, recovery or confidence but has a safe workaround. | Test in the affected layer and schedule a bounded follow-up if not fixed in the increment. |
| **P3 — minor polish** | Low user impact with no credible safety, privacy or data-integrity effect. | Record and fix when proportionate; do not misclassify a recurrent defect as cosmetic. |

Risk is re-assessed when a change crosses an app/service boundary, alters location/audio lifecycle, changes privacy data flow, adds a provider, or changes riding-time interaction.

## 5. Evidence model

The test pyramid is a selection rule, not a release claim. Prefer the lowest level that can falsify the risk; retain higher-level tests for integration and human behaviour.

| Evidence level | What it proves well | Typical RideHorizon use | What it cannot prove |
| --- | --- | --- | --- |
| Static/package review | Configuration, signing, privacy manifest, forbidden build artefacts and documentation consistency. | iPhone-only packaging, Release exclusion of calibration artefacts, policy URLs. | Runtime behaviour. |
| Unit/component test | Deterministic state transitions and transformations. | Boundary priority, announcement suppression, ride inactivity, retry/cancellation, sanitisation and diagnostics bounds. | iOS framework, provider and headset behaviour. |
| Contract/service test | API schema, validation, auth behaviour, retention and coded failure handling. | OpenAPI, proxy controllers, rate limits and provider error mapping. | Deployed configuration and upstream availability. |
| UI automation | Repeatable screen flows, copy, layout and clean-install controls. | Onboarding, consent, credential absence and compact/landscape layout. | Real permissions, backgrounding, audio perception and live GPS. |
| Device integration | Apple frameworks and the actual release candidate on the supported phone. | Permission timing, session lifecycle, background location, audio-session ownership and Bluetooth route changes. | Broad real-road conditions and tester judgement. |
| Field/UAT | The whole rider context: movement, mobile network, helmet, music, navigation, attention, battery and heat. | Owner road UAT and later controlled beta feedback. | Root cause without diagnostics or further investigation. |
| Content-quality review | Human judgement of AI-generated facts in sequence. | Factuality, relevance, novelty, length, tone and safe phrasing across transitions. | Live riding ergonomics unless separately tested. |

No single layer substitutes for another. In particular, speech/audio and background execution require both automated lifecycle evidence and physical evidence.

## 6. Test stages

### 6.1 Change-level verification

For every coherent code change, run the smallest relevant deterministic checks. New deterministic behaviour normally gets a focused test first; uncertain existing behaviour gets characterisation before change. App/proxy contract changes update `FACT_PROXY_OPENAPI.yaml`, its human-readable contract and service/client tests together.

### 6.2 Candidate integration

At a meaningful checkpoint, run the complete iOS unit target, fact-proxy suite, relevant privacy-site tests and a signed physical-device build. Verify real public health/fact/speech paths only through the existing safe operational procedure; never place credentials in commands, logs or evidence.

### 6.3 Phone-only app verification

Before introducing Bluetooth or helmet variables, verify the exact candidate on the physical iPhone. Check clean install, onboarding/consent, idle/start/end lifecycle, proxy recovery, inactivity, screen-lock cleanup and diagnostics. This evidence establishes app behaviour, not the external audio path or tester-feedback tooling.

### 6.4 Stationary helmet verification

Run the exact candidate’s pre-road checks with the primary X-COM2 headset. Confirm Apple Voice/Premium Voice playback, music interruption/restoration, Bluetooth route handling and the diagnostic export. Use the [stationary physical-test protocol](STATIONARY_PHYSICAL_TEST_PROTOCOL.md) for product-test execution. The [X-COM2 setup guide](../operations/headsets/XCOM2_IPHONE_SETUP_AND_STATIONARY_TEST.md) is only the one-time prerequisite for paired-device, voice-path, source-volume and feedback-Shortcut configuration. A new build requires new exact-build evidence where the change could affect the result.

### 6.5 Moving owner acceptance

Only after the stationary gate, execute the compact owner road UAT. It validates continuity, intelligibility, coexistence with music/navigation, opportunistic network recovery and power/thermal acceptability. It never authorises phone interaction while moving.

### 6.6 Content-quality campaign

Evaluate place transitions separately from the road test using representative, privacy-safe sequences. Sample town, county, region and country transitions; outbound/return journeys; familiar and unfamiliar context; short and long facts; repeated nearby places; and failure/fallback paths. Record samples and findings under `docs/evidence/fact-quality/`; do not use raw private ride logs as test fixtures.

Use the [simulated ride and content-assurance plan](SIMULATED_RIDE_AND_CONTENT_ASSURANCE.md) for the GPX-derived replay, sampling and speech-audio approach. It distinguishes deterministic route regression from variable live-provider review and real-road evidence.

## 7. Test data and environments

- Use deterministic fixtures for algorithms, test routes, contract payloads, audio calibration and failure simulation.
- Use synthetic or redacted data in automated tests. Production credentials, tokens, personal coordinates, tester identities and raw ride logs must never enter repository fixtures, console output or documentation.
- Identify every manual run by app version/build, install source, device/iOS, relevant headset and audio/navigation conditions. The field-evidence record owns this information.
- Treat the exact TestFlight binary as a distinct test object. A Debug build, an archive validation, or a previous build is supporting evidence only.
- Test with the primary physical device and Nex Xcom/Sena-derived headset first. Expand the compatibility matrix only after the private-beta commitment has evidence, not by claiming untested compatibility.

## 8. Automation direction

Maintain fast automated coverage around pure policy and lifecycle seams. Add contract tests for every app/proxy contract change and UI tests for safety- or privacy-critical flows. Do not automate a fragile UI path merely to increase a count when a component test proves the rule better.

The current significant gaps are deliberate evidence gaps, not assumed passes: release-configuration UI automation, a GPX-derived deterministic replay harness, deployed end-to-end monitoring, representative sequence-based fact-quality evaluation, cross-version/headset compatibility, accessibility validation on physical hardware, and measured long-ride performance/battery baselines. Shape each as an evidence-bearing work item before implementation or release scope expands.

## 9. Reporting and review

Report: test object, scope, result, evidence, remaining risk and decision needed. Separate observation from diagnosis. Failed or blocked P0/P1 evidence is visible in the relevant Backlog.md task and run record; it is never hidden behind aggregate pass percentages.

At every milestone health gate, compare the current evidence with the next commitment using the Delivery Risk Cube: functional breadth, implementation fidelity and production-quality depth. The product owner then chooses **continue**, **revise**, **refactor**, **research**, **prototype**, **reduce scope**, **pause** or **stop**.

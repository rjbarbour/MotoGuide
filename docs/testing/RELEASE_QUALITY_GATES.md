# RideHorizon Release Quality Gates

Date: 2026-08-05
Status: Active for the private-beta path.

## Purpose

These gates prevent a candidate becoming externally testable merely because it builds or uploads. They define the minimum evidence required to move between controlled stages. The detailed execution rows and results remain in `docs/operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md`.

## Gate sequence

```text
Change evidence
  → candidate integration
  → signed exact-build installation
  → parked pre-road checks
  → owner road UAT
  → release decision
  → external TestFlight review/invitations
```

A later gate does not erase a failed earlier gate. A material new build repeats the evidence affected by the change.

## G0 — Change evidence

**Purpose:** establish that the increment works at its lowest effective level.

Required:

- risk assessment against the [coverage model](QUALITY_RISK_COVERAGE_MODEL.md);
- focused iOS, proxy, UI or site tests for changed deterministic behaviour;
- contract/schema validation for client–proxy changes;
- peer/independent review for P0/P1 or cross-boundary change; and
- documentation, privacy and operational evidence updated where reality changed.

**Exit:** evidence is linked from the work item; no unresolved P0/P1 deterministic failure.

## G1 — Candidate integration and package integrity

**Purpose:** prove that the integrated candidate can be assessed on the real target, without confusing a build with a release.

Required:

- complete iOS unit target at a meaningful checkpoint;
- fact-proxy test suite and affected privacy-site checks pass;
- the executable OpenAPI contract gate passes when its contract changed;
- signed physical-device build succeeds and is installed/launched where the device is available;
- archive/package checks establish correct signing, device scope, privacy manifest, entitlements and exclusion of internal/test artefacts; and
- safe live health/fact/speech verification confirms the deployed dependency path, without exposing credentials.

**Exit:** a named version/build becomes the candidate. Archive and Debug evidence do not yet grant field or external-beta approval.

## G2 — Exact-build stationary safety gate

**Purpose:** prove the candidate’s controlled physical behaviours while the rider is parked.

Required:

- the processed TestFlight binary is installed and its exact version/build recorded;
- clean installation/onboarding confirms no credential prompt, appropriate consent and Test Mode off;
- opening without Start ride remains idle; Start ride, End ride and post-end cleanup are observed;
- Apple Voice and Premium Voice previews complete and release their audio session;
- music coexistence works for both speech providers without sudden perceived volume change or stuck suppression;
- Bluetooth route handling, stopped feedback-capture operability and diagnostic export are assessed where the candidate changed that behaviour; and
- any proxy idle/recovery check remains bounded, with no late duplicate output.

**Exit:** every mandatory pre-road row is Pass on the exact build. A failed audio/lifecycle/privacy row blocks road and external testing unless the feature is safely removed and the revised scope is re-evaluated.

## G3 — Owner road acceptance

**Purpose:** prove the remaining system risks under ordinary riding conditions without inducing unsafe test behaviour.

Required:

- G2 pass;
- execution of the owner [road-UAT protocol](../operations/testflight/RIDE_UAT_PROTOCOL.md) on a representative approximately 60-minute ride;
- place and background continuity with navigation foregrounded and the screen locked;
- at least three intelligible helmet announcements with acceptable music/navigation coexistence and no distracting behaviour;
- opportunistic record of weak-network recovery if encountered; and
- battery/thermal observation, diagnostic preservation and explicit end-of-ride cleanup.

**Exit:** mandatory moving-road rows pass, or any not-observed condition is consciously held for a further valid run. Stationary inactivity and end-of-ride evidence is completed at G2. A serious audio, attention, stale-context, background, crash or thermal result is a release blocker.

## G4 — External beta release decision

**Purpose:** convert evidence into a bounded decision, not an automatic invitation.

Required:

- G0–G3 evidence linked to the exact build;
- all TestFlight administrative/reviewer prerequisites complete;
- no unresolved P0/P1 issue and any accepted P2/P3 risk recorded under the test policy;
- tester scope, support route, privacy information and feedback/incident route are ready; and
- the product owner records one explicit decision: **continue**, **revise**, **refactor**, **research**, **prototype**, **reduce scope**, **pause** or **stop**.

**Exit:** only a recorded **continue** authorises external invitations. The first beta is limited to the stated named-tester scope; widening it is a new gate decision.

## Stop rules

Stop the current test or release path immediately when there is credible evidence of:

- unsafe distraction or any request to interact while moving;
- sudden perceived audio-volume increase, persistent suppression, or serious navigation interference;
- stale/duplicated speech that could mislead a rider;
- unbounded background location, audio or network work;
- credential, precise location, rider-content or other sensitive-data exposure;
- crash or progressive power/thermal failure in a core ride journey; or
- a loss of test-object integrity, such as concurrent installation or an unverified build identity.

Preserve evidence first, make the rider safe, then record the result as Fail or Blocked and create the appropriate delivery follow-up.

## Current application

As reconciled on 2026-08-17, the current evidence record selects `0.12.4 (20260806.221234)` from a locally verified Internal TestFlight receipt. G0/G1 have supporting evidence. The open gate is G2: confirm that exact identity in the installed app, then collect stationary and field evidence under RH-002. This document does not mark that candidate as released or eligible for external invitation.

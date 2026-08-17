# RideHorizon Test Policy

Date: 2026-08-05
Status: Active.

## Purpose

This policy sets the non-negotiable rules for testing RideHorizon. It prevents a common failure mode in mobile companion products: treating a green automated suite as proof that the real rider experience is safe.

## Principles

1. **Rider safety takes precedence over feature breadth, convenience and release date.** Do not ask a rider to operate RideHorizon, ChatGPT or a test instrument while moving. Stop or reduce scope when an observation suggests distraction, stale speech, dangerous audio behaviour or loss of control.
2. **Test evidence must match the claim.** Unit tests prove deterministic logic; physical tests prove iOS/audio/lifecycle behaviour; field tests prove real riding conditions; human review proves content quality and perceived intelligibility.
3. **Test the whole transition, not a happy-path screen.** Location → place estimate → announcement decision → fact → announcement text → TTS → speech audio → playback → session release is the meaningful chain. Include cancellation, supersession, timeout and recovery paths.
4. **Protect privacy while testing.** Test data follows the product’s data minimisation rules. Do not retain precise route/location history, credentials, raw provider bodies, generated rider content, or unnecessary tester identity in source control.
5. **Make failure safe and understandable.** A degraded service must produce bounded silence, a local fallback or concise rider-safe feedback—not stale/duplicate speech, exposed internals or an instruction to troubleshoot while riding.
6. **Use reproducible test objects.** Record version/build, install source, device/iOS and relevant conditions. Do not transfer evidence casually between Debug, archive and TestFlight builds.
7. **Independent evaluation is required for material changes.** The person who implements may repair findings but is not the sole judge of P0/P1 completion.
8. **Do not automate false certainty.** A high test count, a mock provider or a screenshot is not evidence of headset intelligibility, music restoration, background continuity, content truthfulness or battery impact.
9. **Preserve traceability without bureaucracy.** Link risk, test, result, defect and decision. Do not reproduce the same live status in several documents.

## Result definitions

| Result | Meaning |
| --- | --- |
| **Pass** | The defined expected result was observed on the named test object and required evidence was retained. |
| **Fail** | The expected result was not met. Record observed behaviour, safety impact and evidence before attempting a fix. |
| **Blocked** | A valid attempt could not complete because of a named environment, tool, access or dependency problem. A block is not a pass and must name its next action/owner. |
| **Not run** | The test has not been attempted for the stated object. |
| **Not observed** | The test depended on a natural condition that did not arise, such as weak mobile signal. It is not a pass. |
| **Not applicable** | The test does not apply to the stated scope; record why. Do not use this to remove an inconvenient risk. |

## Defect policy

Create a defect or bounded follow-up in `ITEM-BACKLOG.md` when a failure is credible and actionable. Include: build/run ID, expected and observed behaviour, conditions, impact, evidence location, reproducibility, test dimension, severity and retest result.

| Severity | Examples | Release disposition |
| --- | --- | --- |
| **P0** | Unsafe distraction; speech stale after location context changes; sustained navigation/audio interference; unbounded background tracking; credential/sensitive-data exposure; crash in a core ride path. | Stop the affected release path. Fix, reduce scope or obtain an explicit documented product-owner decision before proceeding. |
| **P1** | Core announcement or ride lifecycle fails; permission/consent boundary is wrong; reliable service degradation is absent; private-beta build cannot complete a mandatory acceptance path. | No external-beta release until fixed and retested, unless the affected capability is safely removed. |
| **P2** | Important usability, comprehension, accessibility or recovery problem with a safe workaround. | Fix before broadening the beta where practical; otherwise create a bounded, visible follow-up with an owner and decision date. |
| **P3** | Minor visual/copy issue with no material impact. | Record and schedule proportionately. |

Never downgrade a severity because a failure is difficult to reproduce, has occurred once, or was found late. Evaluate its credible worst-case rider impact.

## Entry criteria

A test stage starts only when its prerequisites are true:

| Stage | Entry criteria |
| --- | --- |
| Component/automated | Requirement or risk is clear; test data is safe; deterministic seams exist or an explicit manual rationale is recorded. |
| Integration/service | Contract is agreed; non-production or safe live verification route is available; no secret needs to be exposed to execute it. |
| Stationary physical | Signed candidate installed; exact build identified; rider is parked; relevant device/headset/audio setup available; no concurrent deployment can change the test object. |
| Moving road UAT | Mandatory stationary checks pass; route and conditions meet the protocol; rider has agreed the no-interaction rule; an unsafe result can be ended safely. |
| External beta | Exact processed TestFlight build passes the release gate, residual risks are explicit, and the product owner makes the milestone decision. |

## Exit criteria and risk acceptance

A test stage completes only when planned results are recorded as Pass, Fail, Blocked, Not observed or Not applicable with evidence. “No issue noticed” is insufficient.

Release cannot pass with an unresolved P0 or P1. A P2/P3 may be accepted only when all of the following are recorded in the delivery ledger or release record:

1. the residual risk and affected users/configurations;
2. why delaying or removing the capability is less proportionate;
3. compensating controls or safe scope limit;
4. owner, expiry/review point and observable follow-up; and
5. explicit product-owner acceptance.

Risk acceptance never overrides a rider’s ability to stop the app or a tester’s decision that the experience is unsafe.

## Evidence handling

- Use the format in `docs/operations/testflight/TESTFLIGHT_FIELD_TEST_EVIDENCE.md` for release/field runs. Keep retained exports outside Git unless they are demonstrably privacy-safe and required as durable evidence.
- Record timestamps in ISO-8601 format and distinguish them from elapsed times.
- Diagnostics may correlate events, but their lack of precise location, fact text, credentials and external-app identity is a privacy control—not a data-quality defect.
- For a failed field result, preserve the first evidence before reinstalling, resetting state or changing settings.
- Attach or link only the minimum evidence needed to support the claim. Summarise sensitive evidence rather than copying it into issue text.

## Change control and regression

Every changed quality-risk area receives targeted regression at its lowest effective level. The following changes always trigger a review of the matching physical/operational evidence:

| Change | Required review |
| --- | --- |
| Ride-session, location, geocoder or announcement-policy behaviour | Lifecycle and stale/supersession tests; stationary/road evidence if real timing or background behaviour can change. |
| Audio session, speech processing, provider or Bluetooth route behaviour | Automated ownership/release tests; stationary audio checks; road/audio UAT where perceptual behaviour can change. |
| Proxy API, auth, quotas, privacy retention or upstream provider handling | OpenAPI/contract and proxy tests; live safe-path verification; privacy review. |
| Onboarding, permissions, consent, diagnostics or data collection | UI/clean-install checks, privacy review and exact-build validation. |
| Build, signing, entitlements, App Store metadata or public pages | Archive/package checks and the relevant review/publishing evidence. |

## Test roles and decision rights

The test manager may block a claimed pass where evidence does not support the claim. The implementer owns correction and focused proof. The independent reviewer judges evidence completeness for material work. The rider tester owns perceptual observations and can stop any test. The product owner alone accepts residual non-blocking risk and makes the release/milestone decision.

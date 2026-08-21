---
id: RH-082
title: Suppress repeated announcements for an unchanged place
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-21 11:46'
updated_date: '2026-08-21 12:47'
labels:
  - core
  - announcement
  - regression
  - road-test
milestone: m-1
dependencies: []
references:
  - 'https://github.com/rjbarbour/MotoGuide/pull/58'
priority: high
type: bug
ordinal: 218000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Road-test regression observed on 2026-08-21: RideHorizon continuously repeats the same place announcement while the place has not changed, apparently once per GPS or place-resolution update. Restore change-driven, sparse announcement behaviour. Scope excludes sequencing a genuinely newer boundary behind active speech, tracked by RH-060 — Finish active announcements before handling newer boundary speech.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Repeated accepted GPS or geocoder updates that resolve to the same meaningful place do not enqueue or speak duplicate announcements
- [x] #2 A genuine eligible town, county, region or country change still produces one announcement according to the configured policy
- [x] #3 The fix does not suppress a valid first announcement after ride start or an explicitly authorised repeat condition
- [ ] #4 Focused automated evidence and a physical road-test check demonstrate that an unchanged place remains quiet across multiple updates
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Trace accepted GPS/place-resolution updates through LocationManager and AnnouncementCoordinator. 2. Keep normal boundary change detection unchanged; confine the explicit every-lookup bypass and its Settings control to Test Mode. 3. Cover live unchanged updates, the first eligible post-start boundary change, and the authorised Test Mode first/repeat path with deterministic asynchronous regressions. 4. Run focused tests and one complete RideHorizonTests simulator checkpoint, obtain independent read-only review, commit and push. 5. Leave physical unchanged-place road validation open; do not merge or build/install on a device.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Captured from the 2026-08-21 road test. Intended branch: codex/rh-082-suppress-unchanged-place-repeats. Coordination only in this session; diagnosis and implementation have not started.

2026-08-21 diagnosis: the normal AnnouncementPolicy already rejects unchanged addresses. Static path analysis found one bypass: Speak after every location lookup forces speech for unchanged addresses and is currently honoured during live rides. The field setting itself is not proven from captured road diagnostics, but this is the only code path that produces the reported unchanged-place behaviour.

2026-08-21 red/green evidence: the live-ride test failed with repeated Stroud and Stonehouse announcements before the fix; the Test Mode repeat test passed. After gating the noisy override to Test Mode, both focused tests passed. The complete RideHorizonTests suite passed 240 tests with 0 failures. Robert's iPhone was not listed by xcodebuild, so physical build/install and unchanged-place road validation remain pending.

Draft PR #58 opened on 2026-08-21. Keep draft until physical unchanged-place road evidence is captured on the supported iPhone.

2026-08-21 independent review found a ride-start coverage gap and timing-sensitive negative assertion. Remediation now starts explicit ride sessions, awaits positive speech requests and uses an inverted request expectation for unchanged updates. Final independent re-review: zero findings; git diff --check passed. Verification in this session: focused RH-082 tests passed 2/2 after final remediation; the complete RideHorizonTests simulator checkpoint passed 240/240 before the test-only review strengthening. No physical-device build, install or road test was performed; acceptance criterion 4 remains open.

2026-08-21 GitHub CI infrastructure note: run 32482827982 failed before build or XCTest because the hosted runner exposed no iPhone 17 Pro simulator destination. No application test failed. The approved GitHub PAT cannot rerun Actions jobs, so this ledger-only evidence commit intentionally retriggers PR validation; no local build or test is applicable.
<!-- SECTION:NOTES:END -->

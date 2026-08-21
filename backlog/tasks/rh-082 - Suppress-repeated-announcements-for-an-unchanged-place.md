---
id: RH-082
title: Suppress repeated announcements for an unchanged place
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-21 11:46'
updated_date: '2026-08-21 12:27'
labels:
  - core
  - announcement
  - regression
  - road-test
milestone: m-1
dependencies: []
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
- [ ] #1 Repeated accepted GPS or geocoder updates that resolve to the same meaningful place do not enqueue or speak duplicate announcements
- [ ] #2 A genuine eligible town, county, region or country change still produces one announcement according to the configured policy
- [ ] #3 The fix does not suppress a valid first announcement after ride start or an explicitly authorised repeat condition
- [ ] #4 Focused automated evidence and a physical road-test check demonstrate that an unchanged place remains quiet across multiple updates
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a failing LocationManager regression proving that the developer noisy-speech flag cannot repeat unchanged places during a live ride, while a genuine place change still announces once. 2. Scope Speak after every location lookup to Test Mode and make the UI constraint explicit. 3. Verify the explicit Test Mode repeat path remains available. 4. Run focused tests and the complete iOS unit-test checkpoint, build/install if the supported iPhone is connected, then push and raise a separate PR.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Captured from the 2026-08-21 road test. Intended branch: codex/rh-082-suppress-unchanged-place-repeats. Coordination only in this session; diagnosis and implementation have not started.

2026-08-21 diagnosis: the normal AnnouncementPolicy already rejects unchanged addresses. Static path analysis found one bypass: Speak after every location lookup forces speech for unchanged addresses and is currently honoured during live rides. The field setting itself is not proven from captured road diagnostics, but this is the only code path that produces the reported unchanged-place behaviour.

2026-08-21 red/green evidence: the live-ride test failed with repeated Stroud and Stonehouse announcements before the fix; the Test Mode repeat test passed. After gating the noisy override to Test Mode, both focused tests passed. The complete RideHorizonTests suite passed 240 tests with 0 failures. Robert's iPhone was not listed by xcodebuild, so physical build/install and unchanged-place road validation remain pending.
<!-- SECTION:NOTES:END -->

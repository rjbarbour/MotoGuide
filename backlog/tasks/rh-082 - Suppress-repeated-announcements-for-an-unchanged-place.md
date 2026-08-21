---
id: RH-082
title: Suppress repeated announcements for an unchanged place
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-21 11:46'
updated_date: '2026-08-21 11:46'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Captured from the 2026-08-21 road test. Intended branch: codex/rh-082-suppress-unchanged-place-repeats. Coordination only in this session; diagnosis and implementation have not started.
<!-- SECTION:NOTES:END -->

---
id: RH-081
title: Restore foreground music interruption during announcements
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-21 11:46'
updated_date: '2026-08-21 12:28'
labels:
  - core
  - audio
  - regression
  - road-test
milestone: m-1
dependencies: []
references:
  - 'https://github.com/rjbarbour/MotoGuide/pull/57'
priority: high
type: bug
ordinal: 217000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Road-test regression observed on 2026-08-21: when RideHorizon is in the foreground and music is playing, a RideHorizon announcement is delivered without pausing the music. Restore the intended foreground audio behaviour without weakening navigation-audio priority. Scope excludes the separate Google Maps background-delivery problem tracked by RH-059 — Restore announcements while Google Maps is foregrounded.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 With RideHorizon foregrounded and music playing, starting an announcement pauses the music so the speech is clearly audible
- [ ] #2 After the announcement completes normally, previously playing music resumes without manual rider action
- [ ] #3 Navigation audio, Stop and End ride retain their existing interruption and cancellation authority
- [ ] #4 Focused automated evidence and a physical iPhone/X-COM2 road-test check cover the foreground music interaction
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a regression test showing that a stale background lifecycle record cannot force mixable playback when the application is currently foreground. 2. Resolve foreground/background state authoritatively at delivery time while retaining the background mix policy required by RH-059. 3. Run focused audio/coordinator tests, then the complete iOS unit-test checkpoint. 4. Build and install on the supported iPhone if connected, capture diagnostics, obtain independent review, and raise a PR.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Captured from the 2026-08-21 road test. Intended branch: codex/rh-081-foreground-music-pause. Coordination only in this session; diagnosis and implementation have not started.

2026-08-21 diagnosis: RH-059 introduced a cached lifecycle gate for audio policy. A stale background value can select the mix policy even while the app is currently foreground, matching the road-test symptom. The fix will use current application state at delivery time and keep the cached value for diagnostics only.

2026-08-21 evidence: focused foreground/background policy tests passed (2 tests, 0 failures). The complete RideHorizonTests suite passed 239 tests with 0 failures. Robert's iPhone was not listed by xcodebuild, so physical build/install and X-COM2 music-pause acceptance remain pending.

Draft PR #57 opened on 2026-08-21. Keep draft until physical foreground music pause/resume evidence is captured on the supported iPhone and X-COM2.
<!-- SECTION:NOTES:END -->

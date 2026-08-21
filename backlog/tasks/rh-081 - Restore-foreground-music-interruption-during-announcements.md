---
id: RH-081
title: Restore foreground music interruption during announcements
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-21 11:46'
updated_date: '2026-08-21 12:50'
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
1. Add deterministic retained-session regressions for background mix to foreground interrupt and foreground interrupt to background mix after a deactivation failure, including consistent activation/playback diagnostics. 2. Make every playback start sample the current delivery/lifecycle policy; activate when ownership is new or the retained policy changed, and avoid redundant activation when unchanged. 3. Verify retained-session retry and End cancellation/release semantics alongside the focused policy tests. 4. Run the complete RideHorizonTests checkpoint, record evidence, commit and push; keep the physical iPhone/X-COM2 gate open and do not merge or device-build.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Captured from the 2026-08-21 road test. Intended branch: codex/rh-081-foreground-music-pause. Coordination only in this session; diagnosis and implementation have not started.

2026-08-21 diagnosis: RH-059 introduced a cached lifecycle gate for audio policy. A stale background value can select the mix policy even while the app is currently foreground, matching the road-test symptom. The fix will use current application state at delivery time and keep the cached value for diagnostics only.

2026-08-21 evidence: focused foreground/background policy tests passed (2 tests, 0 failures). The complete RideHorizonTests suite passed 239 tests with 0 failures. Robert's iPhone was not listed by xcodebuild, so physical build/install and X-COM2 music-pause acceptance remain pending.

Draft PR #57 opened on 2026-08-21. Keep draft until physical foreground music pause/resume evidence is captured on the supported iPhone and X-COM2.

2026-08-21 P1 correction: audio policy is no longer captured when TTS preparation starts. The coordinator resolves the current lifecycle-derived policy once in the playback-start callback immediately before audio-session activation, and uses that resolved policy for activation and playback diagnostics. Deterministic foreground-to-background and background-to-foreground preparation-transition tests first failed against the stale snapshot (4 assertions), then passed after the fix (2 tests, 0 failures); the strengthened diagnostic rerun passed after one simulator test-host bootstrap failure. Complete RideHorizonTests checkpoint passed 239 tests with 0 failures. RH-059 background playback remains mixable; foreground playback remains interrupting. Physical iPhone/X-COM2 music pause/resume acceptance remains open; no device build/install or merge was performed.

2026-08-21 P2 correction: every playback start now samples the current lifecycle-derived audio policy, including when the coordinator still owns the session after deactivation failure. A changed retained policy reactivates/reconfigures the session before playback and records matching activation/playback diagnostics; an unchanged retained policy avoids redundant activation. Background mix to foreground interrupt and the material reverse transition first failed with 6 assertions against stale retained policy, then passed. Focused checkpoint passed 7 tests with 0 failures, covering preparation transitions, both retained-session directions, unchanged-policy reuse, release retry/neutralisation and End-driven release. Complete RideHorizonTests checkpoint passed 241 tests with 0 failures. Physical iPhone/X-COM2 music pause/resume acceptance remains open; no device build/install or merge was performed.
<!-- SECTION:NOTES:END -->

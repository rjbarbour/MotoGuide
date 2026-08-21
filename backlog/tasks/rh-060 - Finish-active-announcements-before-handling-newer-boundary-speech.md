---
id: RH-060
title: Finish active announcements before handling newer boundary speech
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:57'
updated_date: '2026-08-21 09:51'
labels:
  - core
  - audio
  - sequencing
milestone: m-1
dependencies:
  - RH-013.39
references:
  - 'https://github.com/rjbarbour/MotoGuide/pull/46'
modified_files:
  - RideHorizon/AnnouncementPolicy.swift
  - RideHorizonTests/AnnouncementPolicyTests.swift
  - RideHorizonTests/LocationManagerTests.swift
priority: high
type: bug
ordinal: 111000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A newly detected boundary must not cut off RideHorizon speech that is already playing. Let the active announcement finish, then coalesce newer eligible boundary context into the bounded pending slot while preserving navigation-audio, Stop and End ride interruption authority.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A new town, county, region or country trigger never stops announcement audio that has already started
- [ ] #2 Eligible newer context is coalesced into at most one pending announcement and delivered after the active announcement finishes
- [ ] #3 Google Maps audio, the rider Stop action and End ride can still pause, cancel or terminate speech as designed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add failing coordinator tests proving active RideHorizon speech survives newer boundary triggers while the latest eligible context occupies one pending slot. 2. Preserve cancellation authority for navigation audio, Stop and End ride. 3. Deliver a ready pending announcement immediately after normal active-speech completion without bypassing its configured delay. 4. Run focused coordinator tests and the complete simulator checkpoint; defer physical evidence to the owner.

5. Resolve PR #46 review by holding a delivery-ready replacement while any external-audio pause source remains active, then resume the interrupted announcement before delivering the pending replacement.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner authorised batching RH-060 with RH-059 in draft PR #46 and simulator-only integration while AFK. Physical Google Maps/X-COM2 acceptance remains a later gate.

Red/green evidence on 2026-08-20: the new coordinator regression failed because a newer boundary stopped active speech. AnnouncementCoordinator now protects active/interrupted speech, supersedes only fact or pending work, keeps one latest pending announcement, honours its delay, and delivers it after normal speech completion. Navigation interruption, Stop and End ride retain explicit cancellation paths. The focused regression passed and the complete simulator suite passed 223 tests with zero failures. Physical listening remains deferred by owner instruction.

2026-08-21 PR #46 P1 resolution: deliver now also requires external-audio pause sources to be empty. The new regression proves a replacement whose delay expires during navigation audio remains pending, the interrupted announcement resumes first, and the replacement delivers only after resumed speech finishes. Focused simulator verification passed: testDeliveryReadyReplacementWaitsBehindNavigationInterruptedSpeech; 1 test executed, 0 failures, xcodebuild exit 0 and TEST SUCCEEDED. The broader coordinator class was stopped after CoreSimulator launch instability; no full suite, device deployment or road testing was run.

CI correction on 2026-08-21: the first pause guard also prevented the first announcement discovered during already-active navigation audio from entering the deferred slot. Delivery now waits only when a prior interrupted plan already exists; otherwise the first paused announcement is allowed through the existing defer path. Focused verification passed both testAnnouncementDeferredBeforePlaybackResumesThroughCoordinator and testDeliveryReadyReplacementWaitsBehindNavigationInterruptedSpeech: 2 tests, 0 failures.
<!-- SECTION:NOTES:END -->

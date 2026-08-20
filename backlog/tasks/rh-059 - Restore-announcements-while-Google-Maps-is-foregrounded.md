---
id: RH-059
title: Restore announcements while Google Maps is foregrounded
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:57'
updated_date: '2026-08-20 12:14'
labels:
  - core
  - background
  - audio
milestone: m-1
dependencies:
  - RH-013.39
references:
  - >-
    https://developer.apple.com/documentation/coreaudiotypes/avaudiosessionerrorcode/avaudiosessionerrorcodecannotinterruptothers
modified_files:
  - RideHorizon/LocationManager.swift
  - RideHorizon/ContentView.swift
  - RideHorizonTests/LocationManagerTests.swift
priority: high
type: bug
ordinal: 110000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
RideHorizon must continue detecting meaningful triggers and delivering announcements while Google Maps is the foreground app during an active ride. Diagnose the end-to-end location, fact, queue and audio path rather than assuming the failure is only background execution or audio ownership.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 On the exact supported iPhone with RideHorizon backgrounded and Google Maps foregrounded, a meaningful boundary trigger produces the expected helmet-audio announcement
- [ ] #2 Google Maps navigation instructions retain priority, and RideHorizon resumes or defers without silently losing eligible announcements
- [ ] #3 Physical X-COM2 evidence and privacy-safe diagnostics distinguish trigger, generation, queue and playback outcomes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a focused regression test proving that background playback never requests a nonmixable audio-session policy when Interrupt music is enabled. 2. Resolve the delivery-time audio policy from app lifecycle state: preserve foreground interruption, use a mixable background policy, and retain existing navigation interruption handling. 3. Verify focused policy, coordinator and LocationManager behaviour. 4. Build and install the exact candidate on the supported iPhone, then stop for Google Maps and X-COM2 physical evidence.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ready-queue replenishment on 2026-08-19: RH-013.39 — Complete High workflow boundaries merged and its dependency is satisfied. This task is ready for a separate physical-device diagnosis; it is not started by the architecture close-out.

Claimed in delegated implementation session on branch codex/rh-059-google-maps-background. Stop before speculative code changes if no red-capable reproduction or captured diagnostic evidence can distinguish trigger, generation, queue and playback failure.

Diagnosis evidence: retained UAT traces repeatedly show background speechAudioReady followed by audioSessionActivationFailed and cancellation, with foreground playback succeeding. Apple documents cannotInterruptOthers as activation of a nonmixable session while backgrounded. The current Interrupt music setting resolves to the nonmixable interrupt policy regardless of app state.

Red/green evidence on 2026-08-20: the focused background lifecycle test failed because Interrupt music requested the nonmixable interrupt policy while backgrounded; Apple documents that state as cannotInterruptOthers. The fix preserves foreground interruption but resolves background playback to the mixable policy, allowing activation while navigation retains priority. Four focused policy/interruption tests passed; the complete selected iOS suite passed 225 tests with zero failures. Robert's iPhone was not listed by xcodebuild, so build/install and Google Maps/X-COM2 physical acceptance remain pending.
<!-- SECTION:NOTES:END -->

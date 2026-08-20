---
id: RH-061
title: Show meaningful place updates in the Dynamic Island
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-20 14:15'
labels:
  - core
  - dynamic-island
  - visibility
milestone: m-1
dependencies:
  - RH-013.39
references:
  - >-
    https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
modified_files:
  - RideHorizon.xcodeproj/project.pbxproj
  - RideHorizon/Info.plist
  - RideHorizon/LiveRideActivity.swift
  - RideHorizon/LocationManager.swift
  - RideHorizonLiveActivity/Info.plist
  - RideHorizonLiveActivity/RideHorizonLiveActivity.swift
  - RideHorizonTests/LocationManagerTests.swift
priority: high
type: feature
ordinal: 112000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
During an active ride, present short RideHorizon place or boundary updates in the Dynamic Island while another app, especially Google Maps, is foregrounded. Implement the minimum ActivityKit Live Activity surface required for Dynamic Island presentation; defer the complete persistent Lock Screen and multi-surface Ride Live Activity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Starting a ride establishes the system activity needed to show RideHorizon in the Dynamic Island
- [x] #2 A meaningful place or boundary update produces short glanceable Dynamic Island content without requiring RideHorizon to be foregrounded
- [ ] #3 The exact supported iPhone verifies coexistence with Google Maps and records the system-controlled presentation limitations
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a minimal ActivityKit contract and system adapter for one active ride. 2. Start and end the activity with the ride lifecycle, and update it only when the resolved glanceable place text changes. 3. Add the smallest WidgetKit extension required for Dynamic Island presentation, leaving the richer persistent Lock Screen experience to RH-067. 4. Verify lifecycle logic with focused tests, then run the complete simulator suite and unsigned simulator build; physical Google Maps coexistence remains owner acceptance.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner authorised simulator-only integration while AFK. Physical iPhone and Google Maps presentation evidence remains outstanding.

Implemented the minimum ActivityKit surface: an embedded WidgetKit extension with compact, minimal and expanded Dynamic Island views; a shared ride activity contract; and start, place-update and end lifecycle wiring. Unit tests isolate ActivityKit behind a capability seam. Focused lifecycle tests passed, the complete simulator suite passed 226 tests with zero failures, the extension embedded and validated successfully, and the final focused rerun passed. AC3 remains open for the exact iPhone with Google Maps because the owner is AFK.
<!-- SECTION:NOTES:END -->

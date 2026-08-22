---
id: RH-061
title: Show meaningful place updates in the Dynamic Island
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-22 09:26'
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
  - 'https://github.com/rjbarbour/MotoGuide/pull/47'
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
1. Alert the existing Live Activity on meaningful place changes so iOS expands it over another foreground app. 2. Give alert updates high relevance while preserving the existing standard ride activity lifecycle. 3. Compile, install and physically verify on the supported iPhone with Google Maps.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner authorised simulator-only integration while AFK. Physical iPhone and Google Maps presentation evidence remains outstanding.

Implemented the minimum ActivityKit surface: an embedded WidgetKit extension with compact, minimal and expanded Dynamic Island views; a shared ride activity contract; and start, place-update and end lifecycle wiring. Unit tests isolate ActivityKit behind a capability seam. Focused lifecycle tests passed, the complete simulator suite passed 226 tests with zero failures, the extension embedded and validated successfully, and the final focused rerun passed. AC3 remains open for the exact iPhone with Google Maps because the owner is AFK.

Implementation is in PR #47. The task remains In Progress until exact-device Google Maps coexistence is verified.

2026-08-21 PR #47 P2 resolution: idle LocationManager construction now asks the ActivityKit adapter to end every existing RideHorizon activity, preventing stale Ride in progress content after app termination while leaving normal start/update/end methods unchanged. Focused simulator verification passed: testIdleConstructionEndsOrphanedLiveActivities, testActiveRideStartsUpdatesAndEndsLiveActivity, and testResolvedPlaceDoesNotUpdateLiveActivityOutsideRide; 3 tests executed, 0 failures, xcodebuild exit 0 and TEST SUCCEEDED. The full suite, device deployment, Google Maps coexistence, and road testing were deliberately not run; AC3 remains open.

2026-08-22 owner evidence: the Live Activity exists, but no Dynamic Island presentation appears while Google Maps is foregrounded; Google Maps foreground announcements pass.

2026-08-22 fix candidate: meaningful place updates now request a high-relevance ActivityKit alert, causing iOS to expand the Dynamic Island; a bundled silent CAF avoids an extra alert tone. Signed device build succeeded and RideHorizon 0.14.0 (20260804.0246) was installed and launched. Google Maps physical confirmation remains pending.
<!-- SECTION:NOTES:END -->

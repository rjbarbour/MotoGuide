---
id: RH-061
title: Show meaningful place updates in the Dynamic Island
status: To Do
assignee: []
created_date: '2026-08-18 12:58'
updated_date: '2026-08-19 14:28'
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
- [ ] #1 Starting a ride establishes the system activity needed to show RideHorizon in the Dynamic Island
- [ ] #2 A meaningful place or boundary update produces short glanceable Dynamic Island content without requiring RideHorizon to be foregrounded
- [ ] #3 The exact supported iPhone verifies coexistence with Google Maps and records the system-controlled presentation limitations
<!-- AC:END -->

---
id: RH-067
title: Add the complete persistent Ride Live Activity
status: To Do
assignee: []
created_date: '2026-08-18 12:58'
labels:
  - core
  - live-activity
  - visibility
milestone: m-1
dependencies:
  - RH-061
references:
  - >-
    https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
priority: low
type: feature
ordinal: 119000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend the minimal Dynamic Island activity into the lower-priority complete Ride Live Activity: persistent Lock Screen and supported system surfaces, current ride/place state, freshness, stale-state and deterministic End ride behaviour.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The active ride presents useful current place and ride status on the Lock Screen and other supported Live Activity surfaces
- [ ] #2 Updates are sparse, glanceable and freshness-aware, with no duplicate notification stream
- [ ] #3 End ride, automatic ride end, stale state and app relaunch produce deterministic visible outcomes
- [ ] #4 Physical-device evidence covers background updates, Google Maps coexistence and battery impact
<!-- AC:END -->

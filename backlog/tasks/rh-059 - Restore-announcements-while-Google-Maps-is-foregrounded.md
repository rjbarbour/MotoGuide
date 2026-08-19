---
id: RH-059
title: Restore announcements while Google Maps is foregrounded
status: To Do
assignee: []
created_date: '2026-08-18 12:57'
updated_date: '2026-08-19 15:35'
labels:
  - core
  - background
  - audio
  - ready
milestone: m-1
dependencies:
  - RH-013.39
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ready-queue replenishment on 2026-08-19: RH-013.39 — Complete High workflow boundaries merged and its dependency is satisfied. This task is ready for a separate physical-device diagnosis; it is not started by the architecture close-out.
<!-- SECTION:NOTES:END -->

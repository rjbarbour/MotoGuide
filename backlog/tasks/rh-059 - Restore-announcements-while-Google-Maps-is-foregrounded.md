---
id: RH-059
title: Restore announcements while Google Maps is foregrounded
status: To Do
assignee: []
created_date: '2026-08-18 12:57'
updated_date: '2026-08-19 14:28'
labels:
  - core
  - background
  - audio
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

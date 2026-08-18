---
id: RH-060
title: Finish active announcements before handling newer boundary speech
status: To Do
assignee: []
created_date: '2026-08-18 12:57'
labels:
  - core
  - audio
  - sequencing
milestone: m-1
dependencies: []
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

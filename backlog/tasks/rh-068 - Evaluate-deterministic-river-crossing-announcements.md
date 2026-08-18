---
id: RH-068
title: Evaluate deterministic river-crossing announcements
status: To Do
assignee: []
created_date: '2026-08-18 12:58'
labels:
  - parked
  - core
  - geography
dependencies: []
priority: low
type: spike
ordinal: 200000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parked low-priority geography work. Evaluate whether RideHorizon can detect and announce significant river crossings accurately and sparsely without confusing nearby-road travel, parallel routes, repeated bridge samples or geocoder noise. Do not start implementation until the owner explicitly reprioritises it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Owner explicitly reprioritises the work before implementation starts
- [ ] #2 A future spike identifies an acceptable deterministic river dataset, licensing and offline or service boundary
- [ ] #3 Representative tests distinguish true crossings from approaching, following or repeatedly sampling the same river
<!-- AC:END -->

---
id: RH-064
title: Remember delivered fact summaries from the previous three rides
status: To Do
assignee: []
created_date: '2026-08-18 12:58'
labels:
  - core
  - memory
  - privacy
milestone: m-1
dependencies:
  - RH-024
  - RH-063
priority: medium
type: feature
ordinal: 116000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After each completed ride, persist a compact local summary of what the rider actually heard and use the rolling previous three ride summaries as bounded context for later place-fact requests. This is persistent cross-ride memory, separate from current-ride sequence state.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Only announcements that reached delivered playback contribute subjects or anchors; generated, cancelled and superseded work does not
- [ ] #2 The app retains at most three completed-ride summaries, evicts older summaries deterministically and provides a clear-memory control
- [ ] #3 New ride fact requests receive a bounded recently-heard summary without raw coordinates, full ride tracks or complete announcement transcripts
- [ ] #4 Tests cover first ride, rolling retention, End ride persistence, clearing and recovery from invalid stored state
<!-- AC:END -->

---
id: RH-024
title: Make ride fact generation sequence-aware without destroying useful caching
status: To Do
assignee: []
created_date: '2026-08-17 22:42'
updated_date: '2026-08-21 15:33'
labels:
  - core
  - tier-1
  - sequence
  - superseded
dependencies:
  - RH-013.39
  - RH-013.15
priority: low
type: feature
ordinal: 113000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement bounded Tier 1 current-ride context after the reliability and Dynamic Island priorities in milestone m-1: keep a bounded active-ride record of recent place components and fact subjects, pass bounded recent context to the proxy, avoid repetition across nearby announcements, and clear transient state at End ride. Do not add embeddings, vector search, cross-trip memory, server-side ride history or broad prompt-management machinery.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recent place components and fact subjects are retained within explicit size and time bounds for the active ride only.
- [ ] #2 The proxy receives bounded recent context and generated facts avoid materially repeating recent subjects.
- [ ] #3 End ride clears transient sequence state, and fallback, cache and cancellation behaviour remain covered.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
On 2026-08-21, the owner rejected recent-place and recent-fact lists. The prototype was reverted. RH-063 — ongoing per-ride OpenAI conversation now owns continuity.
<!-- SECTION:NOTES:END -->

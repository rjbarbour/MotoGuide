---
id: RH-024
title: Make ride fact generation sequence-aware without destroying useful caching
status: To Do
assignee: []
created_date: '2026-08-17 22:42'
labels:
  - ready
  - core
  - tier-1
dependencies: []
priority: high
type: feature
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement only Tier 1 next: keep a bounded active-ride record of recent place components and fact subjects, pass bounded recent context to the proxy, avoid repetition across nearby announcements, and clear transient state at End ride. Do not add embeddings, vector search, cross-trip memory, server-side ride history or broad prompt-management machinery.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recent place components and fact subjects are retained within explicit size and time bounds for the active ride only.
- [ ] #2 The proxy receives bounded recent context and generated facts avoid materially repeating recent subjects.
- [ ] #3 End ride clears transient sequence state, and fallback, cache and cancellation behaviour remain covered.
<!-- AC:END -->

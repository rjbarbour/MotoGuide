---
id: RH-006
title: Add bounded shared content caches
status: To Do
assignee: []
created_date: '2026-08-17 22:35'
labels:
  - shaping
  - proxy
dependencies: []
type: enhancement
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add small in-memory proxy caches for sanitised facts and raw speech audio only after the private-beta audio path is stable; preserve authentication, abuse limits and complete generation inputs in cache keys.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Cache hits cannot leak personalised content and retain authentication and quota enforcement.
<!-- AC:END -->

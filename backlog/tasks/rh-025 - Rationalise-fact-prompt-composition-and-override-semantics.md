---
id: RH-025
title: Rationalise fact-prompt composition and override semantics
status: To Do
assignee: []
created_date: '2026-08-17 22:42'
labels:
  - shaping
  - core
  - prompt
dependencies: []
type: enhancement
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reduce overlapping prompt policy layers, preserve safety and factual grounding, remove the fixed geographic weighting, convey the base announcement context, and clarify override semantics through a separately scoped implementation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The separately scoped work snapshot-tests final model messages and preserves prompt-injection boundaries.
<!-- AC:END -->

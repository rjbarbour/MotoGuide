---
id: RH-071
title: Suppress duplicate GitHub iOS runs for architecture batches
status: To Do
assignee: []
created_date: '2026-08-18 13:59'
labels:
  - ci
  - architecture
  - test-efficiency
milestone: m-0
dependencies:
  - RH-069
  - RH-070
modified_files:
  - .github/workflows/ci.yml
  - tools/test-changed
  - docs/testing/README.md
priority: high
type: chore
ordinal: 206000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
For the three High architecture batch branches only, suppress the unreliable duplicate GitHub iOS job when the owning batch records the required local iOS evidence. Preserve proxy selection, lightweight pull-request validation and normal CI behaviour for every other branch and change.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 RH-013.36 — dependency foundation, RH-013.37 — ride orchestration and RH-013.38 — announcement orchestration can skip only the GitHub iOS job under an explicit local-evidence marker
- [ ] #2 Proxy and lightweight validation still run when selected, and non-architecture branches retain normal suite selection
- [ ] #3 No standard skip-ci token or broader workflow suppression is introduced
- [ ] #4 The selector fails closed when the marker, branch identity or comparison input is invalid
<!-- AC:END -->

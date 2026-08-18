---
id: RH-057
title: Require descriptions whenever work-item IDs are mentioned
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:48'
updated_date: '2026-08-18 12:50'
labels: []
dependencies: []
modified_files:
  - AGENTS.md
type: docs
ordinal: 101000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Make RideHorizon task references understandable without requiring the reader to know the backlog. Agent responses must pair every work-item ID with a brief title or plain-language description instead of using bare ticket numbers.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 AGENTS.md explicitly requires every mentioned work-item ID to include a brief title or plain-language description
- [x] #2 The rule explicitly prohibits bare ticket-number references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add one standing user-facing reference rule to AGENTS.md. 2. Verify the wording and focused diff.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification passed: automated AGENTS.md assertion confirmed that every work-item reference requires a description and bare ticket identifiers are prohibited; git diff --check passed.
<!-- SECTION:NOTES:END -->

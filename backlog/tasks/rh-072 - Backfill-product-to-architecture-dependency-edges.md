---
id: RH-072
title: Backfill product-to-architecture dependency edges
status: Done
assignee:
  - '@codex'
created_date: '2026-08-19 14:27'
updated_date: '2026-08-19 14:28'
labels: []
dependencies: []
modified_files:
  - backlog/tasks
priority: low
type: docs
ordinal: 208000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Correct the canonical dependency graph so product work cannot be claimed before its genuine architecture prerequisites are integrated. This is metadata-only and changes no product behaviour.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 RH-059, RH-060 and RH-061 depend on RH-013.39
- [x] #2 RH-024 depends on RH-013.39 and RH-013.15
- [x] #3 RH-013.39 records RH-013.38 as its completed prerequisite
- [x] #4 RH-059 is not labelled ready while RH-013.39 remains incomplete
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Apply the dependency and label changes through Backlog.md CLI, verify all affected task JSON in one bulk check, then integrate the documentation-only patch.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Bulk CLI verification passed for all five dependency edges and the RH-059 ready-label removal; git diff --check passed. No builds or tests were run.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Backfilled the genuine product-to-architecture dependencies, removed the premature ready label, and verified the resulting graph through Backlog.md JSON.
<!-- SECTION:FINAL_SUMMARY:END -->

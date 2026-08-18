---
id: RH-058
title: Establish the sequenced core ride priorities milestone
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:56'
updated_date: '2026-08-18 13:08'
labels: []
dependencies: []
modified_files:
  - backlog/milestones
  - backlog/tasks
type: docs
ordinal: 101000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the canonical Backlog milestone for the RideHorizon priorities agreed on 2026-08-18. Capture missing work as independently deliverable tasks, move only matching existing work, and make delivery order and relative priority explicit without starting implementation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A dedicated milestone records the agreed reliability, Dynamic Island, ride-continuity, model, memory, long-fact, Apple-voice and extended Live Activity sequence
- [x] #2 Existing matching work is assigned without repurposing unrelated architecture, recap or geography tasks
- [x] #3 Every milestone task has a clear title, outcome, acceptance criteria, relative priority and deterministic ordering
- [x] #4 River-crossing work is captured as deliberately parked low-priority work outside the active milestone
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create one core ride reliability and continuity milestone. 2. Create each missing priority as an independently deliverable task. 3. Assign RH-024 as the existing current-ride continuity task, set explicit priorities and ordinal sequence, and capture hard dependencies only where required. 4. Keep river crossings parked outside the milestone. 5. Verify the milestone and task metadata through the CLI.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-18 verification: m-1 contains exactly ten ordered tasks covering background reliability, speech sequencing, Dynamic Island visibility, current-ride sequence awareness, model quality, per-ride conversation, three-ride delivered-summary memory, longer facts, Apple voices and the extended Live Activity. RH-024 is the only pre-existing task moved into the milestone. RH-068 remains low priority, parked and outside the milestone. CLI checks confirm deterministic ordinals, explicit priorities, required dependencies and RH-059 as the sole ready item. No product code changed; builds and device deployment were not applicable.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Created and verified the separate Core ride reliability and continuity milestone and its dependency-aware delivery sequence. The ledger checkpoint is ready for review and integration; canonical Done remains gated on merge and post-merge verification.
<!-- SECTION:FINAL_SUMMARY:END -->

---
id: RH-058
title: Establish the sequenced core ride priorities milestone
status: Done
assignee:
  - '@codex'
created_date: '2026-08-18 12:56'
updated_date: '2026-08-18 13:42'
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

Post-merge verification on 2026-08-18: merge commit cb235e4 is an ancestor of current main; the CLI reports m-1 with ten deterministically ordered tasks, RH-059 as the sole ready item, decision-007 accepted, and RH-068 parked outside the milestone. PROJECT.md and MILESTONES.md now reflect the accepted reliability-first direction.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Integrated and post-merge verified m-1 — Core ride reliability and continuity, its ten-task sequence, decision-007, and the parked river-crossing spike. Refreshed the root project-direction documents to match the accepted reliability-first sequence.
<!-- SECTION:FINAL_SUMMARY:END -->

---
id: RH-013
title: Architecture refactor programme
status: To Do
assignee: []
created_date: '2026-08-17 22:35'
updated_date: '2026-08-18 14:00'
labels:
  - shaping
  - architecture
  - programme
milestone: m-0
dependencies: []
references:
  - docs/architecture/plans/ARCHITECTURE_REFACTOR_PLAN.md
priority: high
type: task
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Coordinate the approved RideHorizon architecture refactor through one clean baseline and three executable behaviour-preserving batches. RH-013.01 — settings boundary and RH-013.03 through RH-013.13 — remaining High architecture checkpoints are non-claimable acceptance records inside the batches; RH-013.02 — baseline capture remains independently claimable; RH-013.36 — dependency foundation, RH-013.37 — ride orchestration and RH-013.38 — announcement orchestration own their branches, worktrees, commits and pull requests. Only the baseline and dependency-satisfied batch tasks may be labelled ready. After a batch merges, the coordinator closes its proven checkpoints from current main, closes the batch and replenishes the queue.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every implementation change belongs to one independently reviewable child task linked to the architecture plan and this milestone.
- [ ] #2 No child is claimed until its dependencies are integrated, its deterministic evidence is explicit and its overlap with active work has been checked.
- [ ] #3 Reviewed child pull requests merge serially and main is updated and verified before the next integration decision.
- [ ] #4 The programme completion condition in the architecture plan is independently verified before RH-013 is marked Done.
<!-- AC:END -->

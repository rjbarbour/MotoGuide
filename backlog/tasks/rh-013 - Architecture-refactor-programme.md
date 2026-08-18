---
id: RH-013
title: Architecture refactor programme
status: To Do
assignee: []
created_date: '2026-08-17 22:35'
updated_date: '2026-08-18 13:08'
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
Coordinate the approved RideHorizon architecture refactor through independently claimable child tasks. This parent is a programme container, not an implementation branch or pull request. The architecture plan remains the direction authority. Each child task uses one task ID, branch, worktree, pull request and evidence record. Only ready-labelled children may be claimed. The coordinator checks conceptual and file overlap before delegation, selects the model deliberately, merges reviewed work serially into current main, rebases or refreshes remaining branches, and holds a health gate before replenishing the ready queue.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every implementation change belongs to one independently reviewable child task linked to the architecture plan and this milestone.
- [ ] #2 No child is claimed until its dependencies are integrated, its deterministic evidence is explicit and its overlap with active work has been checked.
- [ ] #3 Reviewed child pull requests merge serially and main is updated and verified before the next integration decision.
- [ ] #4 The programme completion condition in the architecture plan is independently verified before RH-013 is marked Done.
<!-- AC:END -->

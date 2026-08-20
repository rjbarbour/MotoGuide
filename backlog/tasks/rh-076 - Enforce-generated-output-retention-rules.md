---
id: RH-076
title: Enforce generated-output retention rules
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-20 11:10'
labels:
  - hygiene
  - retention
  - build
dependencies: []
priority: medium
type: chore
ordinal: 212000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Complete the generated-output lifecycle introduced by RH-073. Automatically prune abandoned Xcode caches at build-path resolution, add safe task-completion and dependency-cache retention commands, and explicitly protect release archives and evidence from automatic deletion.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Resolving an Xcode DerivedData path automatically prunes task caches unused for seven days while retaining recent and current caches
- [ ] #2 A guarded task-completion command removes known disposable build output plus untracked OS, editor and Python residue without deleting dependency caches, tracked files or release evidence
- [ ] #3 Dependency caches can be pruned after thirty days of inactivity and force-cleaned explicitly under disk pressure, using exact allowlisted paths with ownership, symlink and tracking guards
- [ ] #4 AGENTS.md and testing documentation define the retention lifecycle, completion commands and release-artifact exclusion
- [ ] #5 Focused shell tests prove automatic pruning, task cleanup, age-based retention, explicit force cleanup and safety guards without running application builds
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Extend the DerivedData helper to prune seven-day stale caches silently whenever path is resolved. 2. Add a guarded generated-output utility for task cleanup, thirty-day dependency pruning and explicit disk-pressure cleanup. 3. Add deterministic fixtures for retention, archive exclusion, tracked-file protection and symlink safety. 4. Update AGENTS.md and testing guidance with exact lifecycle commands and expected results. 5. Run focused shell checks, independently review, integrate through one PR, close and clean.
<!-- SECTION:PLAN:END -->

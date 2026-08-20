---
id: RH-073
title: Consolidate and purge disposable build output
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-20 09:17'
labels:
  - hygiene
  - build
  - xcode
dependencies: []
priority: medium
type: chore
ordinal: 209000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remove accumulated reproducible build output from the repository root, preserve release archives outside the checkout, and establish one external DerivedData parent with task-scoped caches that are purged when work completes or becomes stale. Do not alter product behaviour or delete release evidence.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The repository root contains no DerivedData directories, ignored build caches, empty legacy directories or OS metadata after cleanup
- [ ] #2 Release xcarchives are preserved outside the repository before root build output is removed
- [ ] #3 Tracked Python bytecode is removed and ignore rules prevent generated Python, Xcode, proxy and website outputs from being committed
- [ ] #4 Current build and test tooling defaults to one external RideHorizon DerivedData parent with isolated task subdirectories and a safe cleanup command for task-completion and stale-cache purging
- [ ] #5 Focused shell tests prove cleanup path validation, task-scoped deletion and stale-cache retention without running application builds
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Capture exact generated-output and archive inventory. 2. Add a safe external DerivedData convention and deterministic cleanup utility with focused shell tests. 3. Update current build/test tooling and operational instructions to use the external parent. 4. Preserve release archives outside the checkout, then delete only verified generated and redundant local state. 5. Verify root hygiene, tooling tests and independent review; integrate and close.
<!-- SECTION:PLAN:END -->

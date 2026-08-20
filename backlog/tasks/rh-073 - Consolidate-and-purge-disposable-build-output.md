---
id: RH-073
title: Consolidate and purge disposable build output
status: Done
assignee:
  - '@codex'
created_date: '2026-08-20 09:17'
updated_date: '2026-08-20 09:57'
labels:
  - hygiene
  - build
  - xcode
dependencies: []
references:
  - 'https://github.com/rjbarbour/MotoGuide/pull/41'
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
- [x] #1 The repository root contains no DerivedData directories, ignored build caches, empty legacy directories or OS metadata after cleanup
- [x] #2 Release xcarchives are preserved outside the repository before root build output is removed
- [x] #3 Tracked Python bytecode is removed and ignore rules prevent generated Python, Xcode, proxy and website outputs from being committed
- [x] #4 Current build and test tooling defaults to one external RideHorizon DerivedData parent with isolated task subdirectories and a safe cleanup command for task-completion and stale-cache purging
- [x] #5 Focused shell tests prove cleanup path validation, task-scoped deletion and stale-cache retention without running application builds
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Capture exact generated-output and archive inventory. 2. Add a safe external DerivedData convention and deterministic cleanup utility with focused shell tests. 3. Update current build/test tooling and operational instructions to use the external parent. 4. Preserve release archives outside the checkout, then delete only verified generated and redundant local state. 5. Verify root hygiene, tooling tests and independent review; integrate and close.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented one external DerivedData parent with collision-resistant branch/worktree cache paths, exact-cache cleanup, ownership-marker validation and seven-day stale pruning based on an explicit last-used marker. Focused evidence: seven DerivedData safety, isolation, retention and default-path tests pass; the existing TestFlight fixture suite passes 28 tests including external default paths. Local hygiene evidence: 59 ignored root DerivedData directories (about 10 GB) and verified proxy, website, Xcode, Python and OS caches were removed. The complete 162 MB legacy TestFlight folder was preserved at ~/Library/Developer/Xcode/Archives/RideHorizon Legacy 2026-08-20/TestFlight before root build output was removed; it contains ten xcarchives, one exported IPA package and four simulator-smoke evidence directories. No application build, upload or product behaviour change occurred.

Independent review of exact head 15c0771 completed with zero remaining Standards findings and zero remaining Specification findings after correcting root canonicalisation, filesystem ownership, worktree-key collision, freshness-marker coverage and archive-recovery documentation.

PR #41 merged to main as 5834985. Final GitHub head 613a4a3 passed Select relevant tests, the complete iOS unit job, fact-proxy tests, aggregate PR validation and both Socket checks. Post-merge canonical main is clean at 5834985; the checkout is 140 MB, has no root DerivedData directory and reports no ignored residue. Task-cache completion cleanup and seven-day pruning both report that no external cache currently exists.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed about 10 GB of redundant local Xcode caches and roughly 800 MB of other generated output while preserving 162 MB of TestFlight archives and evidence outside the checkout. Integrated one external, ownership-marked DerivedData parent with collision-resistant worktree caches, exact task-completion cleanup and seven-day stale pruning. Verified by seven focused cleanup tests, 28 TestFlight fixture tests, zero-finding Standards and Specification reviews, all six GitHub checks and post-merge root hygiene.
<!-- SECTION:FINAL_SUMMARY:END -->

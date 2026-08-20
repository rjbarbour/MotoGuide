---
id: RH-076
title: Enforce generated-output retention rules
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-20 11:10'
updated_date: '2026-08-20 11:42'
labels:
  - hygiene
  - retention
  - build
dependencies: []
references:
  - 'https://github.com/rjbarbour/MotoGuide/pull/45'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented automatic seven-day pruning in tools/derived-data path. Added tools/generated-output with one completion command that removes the exact task DerivedData and allowlisted disposable outputs, clears untracked OS/Xcode/Python residue, and prunes dependency caches unused for 30 days. Explicit clean-dependencies supports disk-pressure recovery. Exact-path, ownership, tracking and symlink guards protect source and release evidence. Focused evidence: eight DerivedData tests and six generated-output tests pass; no application build ran.

Independent review found tracked-file inspection could fail open, dependency pruning traversed before physical containment checks, file modification time did not prove recent cache use, known IDE output was omitted, required ownership/tracked/ancestor-symlink tests were missing, and task-output deletion could contain release evidence. Corrections now fail closed on Git inspection, preflight containment and ownership before traversal, use explicit dependency last-used markers, retain unmarked caches, cover fact-proxy/out plus IDE/Xcode residue, refuse protected descendants, and add tracked, ownership, ancestor-symlink and Git-failure tests. Gradle and privacy npm entry points refresh markers; a configuration-only Gradle help run passed and refreshed its marker. Final focused evidence: eight DerivedData tests and twelve generated-output tests pass.

Final review corrections preserve xcresult and other evidence-bearing DerivedData subtrees while deleting disposable siblings, reject every symbolic-link path component including in-repository aliases, initialise legacy dependency markers with one 30-day grace period, and mark the proxy .tools cache only at its actual fallback use. Focused evidence: nine DerivedData tests and thirteen generated-output tests pass; bash syntax and diff checks pass; no application build or test ran.

Final hardening routes every dependency-marker write through the guarded helper, rejects marker symlinks and wrong ownership, and fails closed if DerivedData evidence inspection fails. Completion and stale-prune fixtures now prove disposable cache removal while result evidence remains. Final focused evidence: ten DerivedData tests, fourteen generated-output tests, Bash syntax, diff validation and configuration-only Gradle help all pass; no application build or application test ran.

Pull request: https://github.com/rjbarbour/MotoGuide/pull/45. Reviewed implementation head: 753407b.
<!-- SECTION:NOTES:END -->

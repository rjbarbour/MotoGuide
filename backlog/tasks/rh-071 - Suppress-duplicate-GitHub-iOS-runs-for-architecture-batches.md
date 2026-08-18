---
id: RH-071
title: Suppress duplicate GitHub iOS runs for architecture batches
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 13:59'
updated_date: '2026-08-18 14:30'
labels:
  - ci
  - architecture
  - test-efficiency
milestone: m-0
dependencies:
  - RH-069
  - RH-070
modified_files:
  - .github/workflows/ci.yml
  - tools/test-changed
  - tools/tests/test-architecture-ci-suppression.sh
  - docs/testing/README.md
  - backlog/tasks
priority: high
type: chore
ordinal: 206000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
For the three High architecture batch pull requests and their resulting two-parent main merges only, suppress the unreliable duplicate GitHub iOS job after the owning batch record proves its required local evidence. Preserve proxy selection, proxy deployment selection, lightweight validation and normal CI behaviour for every other branch, commit and change.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 RH-013.36 — dependency foundation, RH-013.37 — ride orchestration and RH-013.38 — announcement orchestration can skip only the GitHub iOS job when the matching batch record contains the exact local-evidence line and all acceptance criteria are checked
- [ ] #2 The resulting main push can skip only the GitHub iOS job when it is a two-parent merge with the expected first parent, exact matching trailer and matching present batch record
- [ ] #3 Proxy, proxy deployment and lightweight validation still run when selected, and non-architecture or invalid evidence retains normal suite selection
- [ ] #4 No standard skip-ci token is introduced; branch, evidence, merge and comparison failures remain fail closed and deterministic fixtures run in CI
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add an explicit, fail-closed local-iOS-evidence marker accepted only for RH-013.36, RH-013.37 and RH-013.38 architecture batch branches. 2. Suppress only the GitHub iOS job while preserving proxy selection, deployment selection and lightweight validation. 3. Verify valid and invalid marker/branch combinations without running product suites. 4. Integrate before the first architecture code batch.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ready check on 2026-08-18: RH-069 — test-selection hardening and RH-070 — architecture efficiency are integrated; the task is bounded to workflow/tooling files and can run in parallel with RH-013.02 — baseline capture without sharing DerivedData or product-code files.

Claimed by the coordinator on branch codex/rh-071-architecture-ci-suppression. May execute in parallel with RH-013.02 — baseline capture; no product or DerivedData overlap.

Implementation evidence: PR suppression requires the exact same-repository batch branch suffix, the matching changed task record at head, exact Local-iOS-Evidence line and no unchecked acceptance criteria. Main suppression additionally requires a two-parent merge whose first parent equals the supplied base, the exact final trailer and the matching present task record. Only github_ios becomes false; local ios, proxy and proxy_deploy remain unchanged. bash -n, positive cases for all three batches, missing/malformed/mismatched/fork/unchecked/deleted/direct/non-main cases, invalid-comparison failure, CI fixture wiring and git diff --check passed. No product suite ran.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added fail-closed iOS-only CI suppression for the three architecture batch PRs and their exact merges while preserving local iOS selection, proxy tests, proxy deployment selection and lightweight validation. CI now runs deterministic trust-boundary fixtures; no blanket skip token or product test run was introduced.
<!-- SECTION:FINAL_SUMMARY:END -->

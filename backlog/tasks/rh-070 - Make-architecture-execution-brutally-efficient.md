---
id: RH-070
title: Make architecture execution brutally efficient
status: Done
assignee:
  - '@codex'
created_date: '2026-08-18 13:52'
updated_date: '2026-08-18 14:05'
labels:
  - architecture
  - control-plane
  - test-efficiency
milestone: m-0
dependencies: []
references:
  - docs/architecture/plans/ARCHITECTURE_REFACTOR_PLAN.md
  - RH-071
  - 'https://github.com/rjbarbour/MotoGuide/pull/31'
  - 73fbb7c51076970d503048380e9fbb7add6dfc3b
modified_files:
  - AGENTS.md
  - docs/architecture/plans/ARCHITECTURE_REFACTOR_PLAN.md
  - docs/testing/README.md
  - backlog/tasks
priority: high
type: docs
ordinal: 202000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace per-checkpoint full build and test gates with three coherent High-priority architecture execution batches, focused change-level evidence and a small number of explicit phase gates. Preserve behaviour and safety evidence while removing duplicate local, GitHub and device work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The High architecture sequence is grouped into dependency foundation, ride orchestration and announcement orchestration batches without changing intended architecture outcomes
- [x] #2 Full iOS, Release, proxy and physical-device gates occur only at the documented risk checkpoints; intermediate work uses focused evidence
- [x] #3 RH-071 — Architecture CI suppression blocks code-batch execution until duplicate GitHub iOS work can be suppressed without skipping proxy or lightweight validation
- [x] #4 Stale planning-batch instructions are removed and agents can identify the exact batching, checkpoint lifecycle, commit identity, parallelism and stop rules from current authority
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Update the architecture programme and High checkpoint task contracts through the Backlog CLI. 2. Replace stale plan state with three execution batches and a bounded verification matrix. 3. Add the narrow architecture-programme cadence exception to AGENTS.md and the test-system entry point. 4. Verify task dependencies, full-gate counts, documentation consistency and diff scope without running product suites.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
RH-013.36 through RH-013.38 now own the three executable batches. RH-013.01 and RH-013.03 through RH-013.13 remain outcome checkpoints; RH-013.02 remains the independently executable baseline.

Independent review corrections: baseline is excluded from checkpoint ranges; batch IDs own commits; checkpoint closure is post-merge; RH-004 audio and privacy-safe diagnostics remain explicit; blanket skip-ci is prohibited; verification counts are a default budget with recorded risk exceptions.

Verification: graph check proved baseline -> dependency foundation -> ride orchestration -> announcement orchestration, with twelve checkpoint-only records and the baseline as the sole ready architecture task. Documentation checks proved the default 3/2/1/1 verification budget, retained RH-004 audio/privacy constraints, removal of stale integration instructions and prohibition of blanket skip-ci. Independent review findings were corrected; no product builds or tests were appropriate for this control-plane-only change.

Post-merge verification: PR #31 merged into current main at 73fbb7c. Documentation-only selection skipped iOS and proxy tests; lightweight PR validation and both security checks passed. Current main contains the verified graph, budget and narrow RH-071 follow-up.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Reshaped the High architecture programme into one baseline and three executable batches, replacing repeated per-checkpoint full gates with focused evidence and a default budget of three complete iOS suites, two Release builds, one proxy suite and one final phone install. Added explicit checkpoint lifecycle and batch commit ownership, retained audio/privacy protection, and created RH-071 — Architecture CI suppression for narrow iOS-only CI control.
<!-- SECTION:FINAL_SUMMARY:END -->

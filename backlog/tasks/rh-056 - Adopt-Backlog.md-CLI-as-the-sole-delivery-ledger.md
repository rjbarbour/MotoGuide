---
id: RH-056
title: Adopt Backlog.md CLI as the sole delivery ledger
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-17 22:43'
updated_date: '2026-08-17 22:50'
labels:
  - migration
  - hygiene
  - documentation
dependencies: []
documentation:
  - backlog/docs/history/doc-001 - 2026-08-17-migration-from-ITEM-BACKLOG.md.md
  - backlog/docs/guides/doc-002 - Backlog.md-workflow-and-migration-mapping.md
modified_files:
  - .gitattributes
  - AGENTS.md
  - README.md
  - PROJECT.md
  - MILESTONES.md
  - docs/README.md
  - docs/architecture
  - docs/operations
  - docs/product
  - docs/research
  - docs/testing
  - resources/brand/ridehorizon-rh-d-2026-08-04/README.md
  - backlog.config.yml
  - backlog/
  - ITEM-BACKLOG.md
type: chore
ordinal: 65000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace the manual ITEM-BACKLOG.md authority with the repository-backed MrLesk Backlog.md CLI while preserving history, stable task meaning and repository hygiene. This task changes documentation and control-plane configuration only; it does not change app, proxy, release, credential or TestFlight behaviour.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every defined legacy task is represented with a deliberate status and every unsupported suffix has an explicit mapping.
- [x] #2 The exact former ledger is preserved as CLI document doc-001 before ITEM-BACKLOG.md is removed.
- [x] #3 AGENTS.md, README.md, PROJECT.md and MILESTONES.md route work to Backlog.md without duplicating live status.
- [x] #4 remoteOperations is true and authenticated task, diff and repository-hygiene checks pass.
- [ ] #5 One RH-056 pull request is integrated and main is clean; retained RH-019.01 WIP remains independently reachable and untouched.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Complete the CLI-created task and decision inventory; add the workflow and mapping guide; update project routing; verify preservation and status mapping; retire ITEM-BACKLOG.md; review, publish, integrate and clean up the single documentation-only branch.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Migration verification on 2026-08-17:

- Preserved the former ledger byte-for-byte as doc-001 before removing the root file.
- Created 65 CLI-managed task records: 56 top-level RH tasks and nine mapped children.
- Created doc-002 for workflow, status and legacy-ID mapping, plus six accepted decision records.
- Verified RH-024 is the only ready task, RH-056 is the only active task, and every explicitly parked stream carries the parked label.
- Verified remoteOperations=true, authenticated origin fetch through GH-PERSONAL, parseable task and decision JSON, clean RH-019.01 recovery worktree, local Markdown links and git diff checks.
- Supported Session Vault searches failed with Unable to connect; the skill prohibited filesystem parsing. Applied the current adoption SOP and the indexed prior AI-course migration lessons instead.
- No app build or test was run because the change is documentation and delivery-control configuration only.
<!-- SECTION:NOTES:END -->

---
id: RH-022
title: Remediate CI findings and activate stable gates
status: Done
assignee:
  - '@codex'
created_date: '2026-08-17 22:42'
updated_date: '2026-08-18 13:42'
labels:
  - shaping
  - ci
  - local-dev
dependencies: []
modified_files:
  - .github/workflows/ci.yml
  - tools/test-changed
  - docs/testing/README.md
  - backlog/tasks/rh-022 - Remediate-CI-findings-and-activate-stable-gates.md
type: task
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Resolve known CI findings and enable only stable, evidence-backed gates through separately scoped work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Each activated gate is stable and its remediation evidence is recorded.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Inspect main-branch merge rules and the current test/build entry points.
2. Add one conservative path classifier shared by local and GitHub Actions execution.
3. Add a human-operable local test-selection command, keeping explicit full-suite and physical-device checks available.
4. Make CI select relevant suites for pull requests and retain full suites on main.
5. Verify representative file classifications, the relevant local commands, and the pull-request workflow results.
6. Record merge-rule evidence and any required GitHub-side configuration action.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Branch: codex/rh-022-selective-test-execution. Scope: selective local and PR test execution only; no change to release, deployment, or physical-device gates.

Evidence: classifier cases passed for documentation, iOS, proxy, workflow and full-suite selections. 2026-08-18: 182 iOS unit tests passed on the USB-connected iPhone; fact-proxy Gradle tests passed. GitHub rulesets endpoint returned no applicable rulesets; legacy branch-protection read returned HTTP 403 with GH-PERSONAL, so required-check configuration needs owner confirmation in GitHub Settings.

Post-merge verification on 2026-08-18: pull request #29 is integrated through merge commit 86cffde. On current main, dry-run classification selects neither suite for documentation, iOS only for app source, proxy only for proxy source, and both suites for workflow/tooling changes. No tests were rerun during this post-merge metadata closure.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Integrated selective local and pull-request test-suite selection. Existing evidence records 182 iOS tests and fact-proxy tests passing before merge; post-merge dry runs verified documentation, iOS, proxy and shared-workflow classification on current main.
<!-- SECTION:FINAL_SUMMARY:END -->

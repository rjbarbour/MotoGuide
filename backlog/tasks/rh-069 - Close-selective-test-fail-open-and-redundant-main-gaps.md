---
id: RH-069
title: Close selective-test fail-open and redundant-main gaps
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 13:47'
labels:
  - ci
  - local-dev
dependencies: []
modified_files:
  - tools/test-changed
  - .github/workflows/ci.yml
  - .github/workflows/fact-proxy-deploy.yml
priority: high
type: chore
ordinal: 201000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Make the merged selective-test framework fail closed locally and stop documentation-only main changes from running product suites or deploying the fact proxy. Keep the change limited to test/deploy selection; do not restructure test targets or alter TestFlight tooling.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An invalid comparison base exits non-zero instead of selecting no tests
- [ ] #2 Untracked, non-ignored local files participate in suite selection
- [ ] #3 A documentation-only push to main selects neither product suite
- [ ] #4 The fact proxy deploy job runs only when fact-proxy or shared proxy-contract inputs changed
- [ ] #5 TestFlight deployment tooling is unchanged
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Make comparison collection fail closed and include untracked local paths.
2. Use before/head comparison for main pushes.
3. Gate fact-proxy deployment with the same classifier.
4. Verify classification only; do not run product test suites.
<!-- SECTION:PLAN:END -->

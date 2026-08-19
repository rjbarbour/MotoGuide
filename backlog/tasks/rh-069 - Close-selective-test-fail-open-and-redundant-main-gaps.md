---
id: RH-069
title: Close selective-test fail-open and redundant-main gaps
status: Done
assignee:
  - '@codex'
created_date: '2026-08-18 13:47'
updated_date: '2026-08-19 10:48'
labels:
  - ci
  - local-dev
dependencies: []
references:
  - 'https://github.com/rjbarbour/MotoGuide/pull/30'
modified_files:
  - tools/test-changed
  - .github/workflows/ci.yml
  - .github/workflows/fact-proxy-deploy.yml
  - docs/testing/README.md
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
- [x] #1 An invalid comparison base exits non-zero instead of selecting no tests
- [x] #2 Untracked, non-ignored local files participate in suite selection
- [x] #3 A documentation-only push to main selects neither product suite
- [x] #4 The fact proxy deploy job runs only when fact-proxy or shared proxy-contract inputs changed
- [x] #5 TestFlight deployment tooling is unchanged
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Make comparison collection fail closed and include untracked local paths.
2. Use before/head comparison for main pushes.
3. Gate fact-proxy deployment with the same classifier.
4. Verify classification only; do not run product test suites.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification on 2026-08-18: shell syntax and diff checks passed; an invalid base exited non-zero; a temporary untracked Swift file selected iOS only; documentation selected neither suite; proxy source selected proxy only. No iOS, Gradle, build, deploy or TestFlight command was run.

Independent review corrections: deployment now consumes the full push-range selection artifact and uses a deploy-specific output limited to fact-proxy/** and FACT_PROXY_OPENAPI.yaml. Documentation now includes non-ignored untracked paths.

Post-merge closure verified on current main d2d8332 on 2026-08-19: invalid comparison failed closed; a temporary non-ignored untracked Swift file selected iOS; documentation selected neither suite; proxy source selected proxy and proxy deployment only; workflow changes selected both suites without proxy deployment. bash syntax passed. No product suite, build, deployment or TestFlight command was run.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Closed the merged selective-test hardening from PR #30. Verified fail-closed comparisons, untracked-file selection, documentation-only suppression, narrow proxy deployment selection and unchanged TestFlight scope on current main.
<!-- SECTION:FINAL_SUMMARY:END -->

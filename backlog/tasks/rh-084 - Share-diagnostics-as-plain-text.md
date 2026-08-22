---
id: RH-084
title: Share diagnostics as plain text
status: Done
assignee:
  - '@codex'
created_date: '2026-08-22 08:55'
updated_date: '2026-08-22 09:23'
labels:
  - ios
  - diagnostics
  - reliability
dependencies: []
references:
  - 'https://github.com/rjbarbour/MotoGuide/pull/64'
  - 'https://github.com/rjbarbour/MotoGuide/actions/runs/32564287560'
modified_files:
  - RideHorizon/ContentView.swift
  - RideHorizon/RideDiagnosticsStore.swift
  - RideHorizonTests/LocationManagerTests.swift
  - docs/operations/testflight/RIDE_UAT_PROTOCOL.md
priority: high
type: bug
ordinal: 220000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The diagnostics screen currently exposes both a dedicated Copy action and a file-based Export share action. Use one Export diagnostics action whose share-sheet Copy operation places the current privacy-safe diagnostic JSON on the clipboard as plain text, avoiding file or rich attachment representations.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The diagnostics screen exposes one Export diagnostics action and no separate Copy diagnostics action
- [x] #2 Selecting Copy from the diagnostics share sheet yields current valid JSON as plain text without styling or a file attachment
- [x] #3 The shared text remains privacy-safe and does not wait for delayed file persistence
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Replace the URL-based diagnostics ShareLink with the current in-memory JSON String and remove the redundant clipboard-specific UI and helper. 2. Adapt the focused regression to verify the shared String is current, valid and privacy-safe. 3. Run the focused diagnostics tests, commit, push, open a PR, and merge after CI passes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Red evidence: the focused test failed to compile because RideDiagnosticsShare did not exist. The former Export diagnostics ShareLink supplied a file URL, so share-sheet Copy could copy a file/attachment representation; the dedicated Copy button wrote plain text but duplicated the UI. The fix removes the pasteboard-specific action and supplies the current privacy-safe JSON String to the single Export diagnostics ShareLink. The focused regression and six diagnostics tests passed with zero failures.

PR #64 opened from commit 5a7a3bc after rebasing against current origin/main.

Automated PR review correctly identified that the active UAT protocol still required attaching ride-diagnostics.json. Updated it to instruct Copy and paste of the complete plain JSON text, or direct sharing to a plain-text-capable app.

Post-merge verification: PR #64 was squash-merged as 302f3e5d. Current origin/main contains the single String-based Export diagnostics ShareLink and the updated UAT instructions. Final GitHub iOS suite passed in 9m38s; PR validation and Socket checks passed; proxy tests were correctly skipped. Residual field check: confirm the receiving app displays the pasted JSON legibly as plain text.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaced the duplicate Copy plus file-export controls with one Export diagnostics action that shares current privacy-safe JSON as a plain String. Updated the UAT protocol for plain-text Copy/paste. The red regression, six focused diagnostics tests, full GitHub iOS suite, review correction and post-merge current-main inspection passed; merged in PR #64 at 302f3e5d.
<!-- SECTION:FINAL_SUMMARY:END -->

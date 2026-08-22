---
id: RH-084
title: Share diagnostics as plain text
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-22 08:55'
updated_date: '2026-08-22 09:03'
labels:
  - ios
  - diagnostics
  - reliability
dependencies: []
modified_files:
  - RideHorizon/ContentView.swift
  - RideHorizon/RideDiagnosticsStore.swift
  - RideHorizonTests/LocationManagerTests.swift
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
- [ ] #1 The diagnostics screen exposes one Export diagnostics action and no separate Copy diagnostics action
- [ ] #2 Selecting Copy from the diagnostics share sheet yields current valid JSON as plain text without styling or a file attachment
- [ ] #3 The shared text remains privacy-safe and does not wait for delayed file persistence
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Replace the URL-based diagnostics ShareLink with the current in-memory JSON String and remove the redundant clipboard-specific UI and helper. 2. Adapt the focused regression to verify the shared String is current, valid and privacy-safe. 3. Run the focused diagnostics tests, commit, push, open a PR, and merge after CI passes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Red evidence: the focused test failed to compile because RideDiagnosticsShare did not exist. The former Export diagnostics ShareLink supplied a file URL, so share-sheet Copy could copy a file/attachment representation; the dedicated Copy button wrote plain text but duplicated the UI. The fix removes the pasteboard-specific action and supplies the current privacy-safe JSON String to the single Export diagnostics ShareLink. The focused regression and six diagnostics tests passed with zero failures.
<!-- SECTION:NOTES:END -->

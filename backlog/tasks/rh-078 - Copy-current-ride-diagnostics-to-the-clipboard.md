---
id: RH-078
title: Copy current ride diagnostics to the clipboard
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-21 11:36'
updated_date: '2026-08-21 11:52'
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
ordinal: 216000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Release diagnostics screen exposes a file ShareLink. Selecting Copy from the share sheet does not place the diagnostic JSON on the clipboard, and the file may lag current in-memory events because persistence is asynchronous. Add an explicit stopped-use Copy diagnostics action that copies the privacy-safe current diagnostic JSON directly and confirms success.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tapping Copy diagnostics places non-empty valid diagnostic JSON from the current in-memory entries on the system clipboard.
- [ ] #2 Copy works after a ride stops without waiting for delayed file persistence and does not copy coordinates, announcement text or credentials.
- [ ] #3 A focused regression test drives the clipboard action through an injected pasteboard and the relevant iOS tests pass.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a focused clipboard regression around an injected pasteboard and current in-memory diagnostics. 2. Add privacy-safe JSON text export independent of delayed file persistence. 3. Replace the ambiguous share-sheet Copy route with an explicit Copy diagnostics action and visible success acknowledgement while retaining file export. 4. Run the focused iOS regression and relevant diagnostics tests, then commit, push, review and merge.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Red evidence: the focused clipboard test initially failed to compile because no DiagnosticsPasteboardWriting or RideDiagnosticsClipboard action existed. Implementation adds an explicit injectable clipboard action, serialises current in-memory privacy-safe entries without waiting for file persistence, disables Copy when empty, and shows copied/no-data status while retaining file export. The focused regression passed and asserts valid JSON plus absence of latitude, longitude, announcementText and credential fields. Five focused diagnostics clipboard/persistence tests passed with 0 failures. One earlier simulator attempt was killed before test bootstrap; the bounded retry passed.

Final original-repro rerun passed after removing unnecessary system pasteboard readback; the production action writes once and reports success without reading clipboard contents.
<!-- SECTION:NOTES:END -->

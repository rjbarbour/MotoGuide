---
id: RH-078
title: Copy current ride diagnostics to the clipboard
status: To Do
assignee:
  - '@codex'
created_date: '2026-08-21 11:36'
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

---
id: RH-064
title: Remember delivered fact summaries from the previous three rides
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-21 11:43'
labels:
  - core
  - memory
  - privacy
milestone: m-1
dependencies:
  - RH-063
priority: medium
type: feature
ordinal: 116000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After each completed ride, persist a compact local summary of what the rider actually heard and use the rolling previous three ride summaries as bounded context for later place-fact requests. This is persistent cross-ride memory, separate from current-ride sequence state.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Only announcements that reached delivered playback contribute subjects or anchors; generated, cancelled and superseded work does not
- [ ] #2 The app retains at most three completed-ride summaries, evicts older summaries deterministically and provides a clear-memory control
- [ ] #3 New ride fact requests receive a bounded recently-heard summary without raw coordinates, full ride tracks or complete announcement transcripts
- [ ] #4 Tests cover first ride, rolling retention, End ride persistence, clearing and recovery from invalid stored state
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a bounded UserDefaults-backed previous-ride memory module that deterministically compacts delivered fact content, retains three summaries, clears explicitly and treats invalid stored data as empty. 2. Carry generated fact content through announcement sequencing and record it only after completed speech playback; compact the active ride at End ride and clear all transient/persistent memory through the appropriate controls. 3. Add previousRideSummaries as a dedicated app-proxy request field independent of active-ride previous_response_id linkage, with no recent-place list, and update validation, prompts, OpenAPI, architecture and privacy wording. 4. Add focused Swift and proxy tests for first ride, delivery gating, rolling retention, End ride, request injection, explicit/all-local clearing and invalid persisted state. 5. Run only focused changed simulator and proxy tests, review against RH-064 and repository standards, resolve findings, commit and push the RH-064 branch, and leave the worktree clean without merge, deploy or device build.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-21 coordination: @codex owns codex/rh-064-three-ride-memory, stacked after RH-028 — bounded hosted web search. RH-024 — recent-list sequence context is obsolete for this outcome; RH-063 — bounded OpenAI conversation per active ride remains the dependency. Exclusions: no raw coordinates or tracks, no complete announcement transcripts, no recent-place list, no merge, deployment or device build.
<!-- SECTION:NOTES:END -->

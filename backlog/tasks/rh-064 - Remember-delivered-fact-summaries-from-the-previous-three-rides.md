---
id: RH-064
title: Remember delivered fact summaries from the previous three rides
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-21 14:30'
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
- [x] #1 Only announcements that reached delivered playback contribute subjects or anchors; generated, cancelled and superseded work does not
- [x] #2 The app retains at most three completed-ride summaries, evicts older summaries deterministically and provides a clear-memory control
- [x] #3 New ride fact requests receive a bounded recently-heard summary without raw coordinates, full ride tracks or complete announcement transcripts
- [x] #4 Tests cover first ride, rolling retention, End ride persistence, clearing and recovery from invalid stored state
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a bounded UserDefaults-backed previous-ride memory module that deterministically compacts delivered fact content, retains three summaries, clears explicitly and treats invalid stored data as empty. 2. Carry generated fact content through announcement sequencing and record it only after completed speech playback; compact the active ride at End ride and clear all transient/persistent memory through the appropriate controls. 3. Add previousRideSummaries as a dedicated app-proxy request field independent of active-ride previous_response_id linkage, with no recent-place list, and update validation, prompts, OpenAPI, architecture and privacy wording. 4. Add focused Swift and proxy tests for first ride, delivery gating, rolling retention, End ride, request injection, explicit/all-local clearing and invalid persisted state. 5. Run only focused changed simulator and proxy tests, review against RH-064 and repository standards, resolve findings, commit and push the RH-064 branch, and leave the worktree clean without merge, deploy or device build.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-21 coordination: @codex owns codex/rh-064-three-ride-memory, stacked after RH-028 — bounded hosted web search. RH-024 — recent-list sequence context is obsolete for this outcome; RH-063 — bounded OpenAI conversation per active ride remains the dependency. Exclusions: no raw coordinates or tracks, no complete announcement transcripts, no recent-place list, no merge, deployment or device build.

2026-08-21 verification: focused Swift simulator evidence passed 13 tests with 0 failures for first ride, deterministic compaction, rolling retention, invalid-state recovery, completed-playback gating, End ride persistence, manager/request injection, cache separation, active-ride linkage, shared fixtures and clearing. Review fixes then passed 8 focused Swift tests with 0 failures, including missing-voice cancellation and superseded-fact exclusion. Focused proxy evidence passed 65 tests with 0 failures across OpenAiServiceTest, PlaceInputValidatorTest, FactControllerTest, OpenApiContractTest and SharedContractFixtureTest. Independent standards/spec review found privacy wording and false Apple no-voice completion gaps; both were fixed and re-review reported no remaining findings. Residual gate: branch is not merged, deployed or device-built by explicit owner instruction, so RH-064 remains In Progress.

2026-08-21 final dependency-base reconciliation: rebased exactly RH-064 commits 0c7216b, 1f7df83 and a8ef2eb from old RH-028 base 5e66cfb onto final RH-028 commit e3a76c9. The only manual conflict was OpenApiContractTest: preserved contract version 0.5.0 and recalculated the combined FACT_PROXY_OPENAPI.yaml SHA-256 as d060884bbd1b042f7550920a826b07b9b19ec9e4432b7d8f007886cd8f2d8f45. Final RH-028 mandatory sources decoding, canonical ASCII URL validation, source-count/malformed-source fail-closed behaviour and invalid-response mapping remain intact. One RH-064 mock response was updated to include the now-required explicit sources:[] field. Final dependency-base evidence: existing focused Swift set passed 13/13; existing review-fix Swift set passed 8/8; the unchanged five-class focused proxy command passed 67/67 because final RH-028 adds two tests to the previously recorded 65-test set.

2026-08-21 current-main merge reconciliation: resolved the in-progress merge of origin/main 1e3908579d62c3684cd49f4abea5c629021b0867 without aborting. The three conflicts preserved current-main RH-028 immutable announcement Log attribution context, RH-081 playback-time audio policy, RH-082 unchanged-place repeat suppression, RH-066 injected voice catalogue dependencies and RH-078 diagnostics clipboard status/control, together with RH-064 delivered-fact tracking, previous-ride memory injection/count, End-ride compaction, explicit/all-local clearing, request summaries and tests. ContentView retains both clear-memory confirmation and diagnosticsCopyStatus. Terminal result handling appends completed delivered fact content before removing both factContentByAnnouncementID and announcementLogContexts; cancellation/failure remove both without delivery. The active-ride identity test retains expectation-based timing and now asserts previousRideSummaries. Verification: git diff --check passed; focused RH-064 Swift 13/13; RH-064 review-fix Swift 8/8; current-main attribution-context cleanup 3/3; focused proxy 67/67. No PR merge or deployment performed.

2026-08-21 PR #60 GitHub CI infrastructure note: run 32492258614 failed before build or XCTest because the hosted runner exposed no iPhone 17 Pro simulator destination. No application test failed. The approved GitHub PAT cannot rerun Actions jobs, so this ledger-only evidence commit intentionally retriggers PR validation; no local build or test is applicable.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented bounded local summaries for the latest three completed rides from fact content that actually finished speech playback. End ride deterministically compacts delivered content without coordinates or tracks; invalid storage recovers empty; explicit and all-local clearing remove memory. Later fact requests receive a dedicated previousRideSummaries body field separate from active-ride previous_response_id linkage and without a recent-place list. Rebased exactly the three RH-064 commits onto final RH-028 e3a76c9 while preserving its citation/source fail-closed contract; combined OpenAPI 0.5.0 hash is d060884bbd1b042f7550920a826b07b9b19ec9e4432b7d8f007886cd8f2d8f45. Verified on the final base with focused Swift 13/13 plus 8/8 and the unchanged focused proxy command at 67/67; independent review remains resolved. Awaiting integration; no merge, deployment or device build performed.
<!-- SECTION:FINAL_SUMMARY:END -->

---
id: RH-063
title: Maintain one bounded OpenAI conversation per active ride
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-21 10:46'
labels:
  - core
  - model
  - session
milestone: m-1
dependencies:
  - RH-062
references:
  - 'https://developers.openai.com/api/docs/guides/latest-model'
  - >-
    https://developers.openai.com/api/reference/cli/resources/responses/methods/create
  - >-
    https://developers.openai.com/api/reference/java/resources/responses/methods/compact
priority: high
type: feature
ordinal: 115000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Use one bounded OpenAI Responses API conversation for each active ride. Successive place-fact requests continue through supported response linkage so the model knows what it previously said. Compact the conversation when needed, clear linkage at End ride, and do not send a parallel list of recent place names.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The first eligible fact request in a ride establishes Responses API state and later fact requests continue it through supported conversation linkage
- [x] #2 The conversation compacts at a bounded threshold without replacing application-owned ride lifecycle and delivered-announcement evidence
- [x] #3 End ride clears provider linkage; expired or failed provider state restarts safely without carrying context into a new ride
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Replace proxy-process conversation storage and the End-ride DELETE call with app-owned per-ride previous_response_id linkage carried through bounded response headers. 2. Serialise active-ride fact calls in the app, discard linkage locally on End ride or terminal failure, and let the proxy retry statelessly only when OpenAI returns a structured error whose param is previous_response_id. 3. Bypass the persisted cross-ride fact cache whenever a rideSessionID is present so every delivered active-ride fact advances the same provider conversation. 4. Update OpenAPI, implementation documentation and the public privacy disclosure for store:true application-state retention of at least 30 days. 5. Add focused Swift and Java regression tests, run only the focused suites, commit RH-063, resolve GH-PERSONAL through GH-01, push the branch, and leave the worktree clean.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner rejected a separate recent-place-list payload on 2026-08-21. Provider conversation state must carry what the model actually said.

2026-08-21: Loaded current OpenAI conversation-state and compaction guidance. Selected supported previous_response_id chaining plus server-side context_management compaction; no recent-place list and no web_search.

2026-08-21 implementation evidence: focused Swift simulator suite passed 79 tests with 0 failures; focused Java OpenAiServiceTest, FactControllerTest and OpenApiContractTest passed 33 tests with 0 failures. The app sends the active ride UUID only as X-RideHorizon-Ride-Id after eligible consent-gated fact work, preserves the existing fact JSON/cache key, and sends authenticated best-effort End-ride clear. The proxy serialises one previous_response_id chain per authenticated subject/ride, resends safety instructions, enables server-side compaction at 24000 rendered tokens, clears failed linkage, retries once without linkage only for an invalid previous response, and does not add web_search or a recent-place list.

2026-08-21 independent review follow-up: process-local proxy linkage, best-effort remote cleanup, active-ride cache bypass, broad expired-link matching and incomplete store:true retention disclosure must all be corrected before hand-off.

2026-08-21 independent review findings resolved: app-owned previous_response_id linkage is serialised locally and survives proxy restarts or machine changes; the proxy retains no ride linkage and End ride performs no fallible remote cleanup; active-ride fact requests bypass and do not populate the persisted cross-ride cache; any terminal app-proxy failure discards local linkage; expired-link replay requires HTTP 400/404 plus structured error.param=previous_response_id; and OpenAPI, implementation docs and the public privacy policy disclose store=true application-state retention of at least 30 days and that End ride does not delete provider state. Final focused evidence: 81 Swift tests passed with 0 failures; OpenAiServiceTest 9, FactControllerTest 24 and OpenApiContractTest 2 passed with 0 failures (35 proxy tests total). Status remains In Progress because this ledger has no Review status and the branch is not merged.

2026-08-21 rebase evidence: rebased exactly the two RH-063 commits from old RH-062 base 89b9c85 onto final RH-062 commit b0b9861f41e954a7da391cf0a0150a7fd69a97c0. Conflict resolution preserves RH-062 non-ride store=false, the 4096 max_output_tokens ceiling and rejection of any response whose status is not completed; RH-063 changes store to true and enables compaction only for app-owned ride-linked calls. Exact dependency-base checks passed: 81 focused Swift tests with 0 failures and 35 focused proxy tests with 0 failures (OpenAiServiceTest 9, FactControllerTest 24, OpenApiContractTest 2).
<!-- SECTION:NOTES:END -->

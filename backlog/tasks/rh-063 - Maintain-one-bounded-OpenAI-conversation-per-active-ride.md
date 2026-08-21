---
id: RH-063
title: Maintain one bounded OpenAI conversation per active ride
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-21 10:10'
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
1. Extend the app-proxy contract with a bounded ride-session header on eligible fact calls and an authenticated End-ride clear operation; keep fact JSON and local cache keys unchanged. 2. Maintain one synchronised previous_response_id chain per authenticated proxy subject and ride UUID, resend safety instructions every turn, and enable server-side compaction with an explicit compact_threshold. 3. Clear linkage at End ride and on provider failure; retry once without linkage only for an invalid/expired previous response, while preserving existing timeout, sanitisation, retry, consent and fallback behaviour. 4. Add focused Swift lifecycle/contract tests and Java conversation/compaction/recovery tests, then run the exact focused suites and record evidence.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner rejected a separate recent-place-list payload on 2026-08-21. Provider conversation state must carry what the model actually said.

2026-08-21: Loaded current OpenAI conversation-state and compaction guidance. Selected supported previous_response_id chaining plus server-side context_management compaction; no recent-place list and no web_search.

2026-08-21 implementation evidence: focused Swift simulator suite passed 79 tests with 0 failures; focused Java OpenAiServiceTest, FactControllerTest and OpenApiContractTest passed 33 tests with 0 failures. The app sends the active ride UUID only as X-RideHorizon-Ride-Id after eligible consent-gated fact work, preserves the existing fact JSON/cache key, and sends authenticated best-effort End-ride clear. The proxy serialises one previous_response_id chain per authenticated subject/ride, resends safety instructions, enables server-side compaction at 24000 rendered tokens, clears failed linkage, retries once without linkage only for an invalid previous response, and does not add web_search or a recent-place list.
<!-- SECTION:NOTES:END -->

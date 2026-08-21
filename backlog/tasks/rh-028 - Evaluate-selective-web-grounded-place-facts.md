---
id: RH-028
title: Web-search-enabled place facts
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-17 22:42'
updated_date: '2026-08-21 11:09'
labels:
  - proxy
  - model
  - web-search
milestone: m-1
dependencies:
  - RH-063
references:
  - 'https://developers.openai.com/api/docs/guides/tools'
  - >-
    https://developers.openai.com/api/reference/resources/responses/methods/create
  - >-
    https://developers.openai.com/api/docs/guides/tools-web-search#output-and-citations
  - 'https://developers.openai.com/api/docs/guides/reasoning#phase-parameter'
priority: high
type: feature
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Offer OpenAI hosted web search as a model-controlled tool for ride-safe place-fact generation on top of RH-063, while preserving application-owned ride linkage and compaction, output limits, response validation, sanitisation and privacy boundaries.

Scope: proxy Responses request construction; completed final-answer selection; bounded url_citation extraction; structured fact-source contract; source propagation through generation, cache and existing Log display; clickable visual attribution that never enters announcement text or TTS; bounded failure/cost diagnostics and fallback classification; focused changed proxy and Swift simulator tests; and necessary OpenAPI, implementation-contract and privacy wording.

Exclusions: no recent-place list, no change to GPT-5.6 Sol medium, no spoken citation text, no general Log redesign, no deployment, merge or device build.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Responses request exposes model-controlled hosted web_search.
- [ ] #2 Searched and unsearched outputs satisfy the existing ride-safe text and privacy contract.
- [ ] #3 Timeout, provider failure and tool-cost diagnostics and fallback remain bounded and tested.
- [ ] #4 Web-derived facts return bounded structured sources parsed from final-response url_citation annotations, and the existing RideHorizon Log displays those sources as clearly visible clickable links without adding citation titles or URLs to announcement text or TTS.
- [ ] #5 Any generated fact that can later be displayed carries its sources through the app pipeline and cache; otherwise that web-derived fact is not cached.
- [ ] #6 When message phase is present, only a completed final_answer message is accepted; a completed phase-less message remains compatible, while commentary and incomplete message paths are rejected.
- [ ] #7 openai_result and its diagnostics-only fields are documented as bounded and privacy-safe, excluding search queries, results, sources, place text and rider text.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Preserve the RH-063 implementation base; do not import later dependency-only test/ledger commits that do not change the production contract.
2. Add focused proxy tests for bounded url_citation parsing, structured sources, source sanitisation/deduplication, completed final_answer selection, phase-less compatibility, and commentary/incomplete rejection.
3. Extend the proxy result and app-proxy JSON/OpenAPI contract with bounded fact sources while leaving announcement text unchanged.
4. Add focused Swift tests, then carry sources through ProxyFactGenerator, PlaceFactGenerating and any cache/display path that can reach the existing Log.
5. Render clearly visible clickable source links only in the existing Log detail; keep titles/URLs out of announcement text and TTS inputs.
6. Document openai_result privacy-safe fields and update the minimum necessary proxy, contract and privacy wording using official OpenAI citation and phase guidance.
7. Run only focused changed proxy tests and focused Swift simulator tests selected for the changed files; use the review skill, resolve all findings, commit and push RH-028, and leave the worktree clean without merge, deployment or device build.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-21: Claimed on branch codex/rh-028-web-search from RH-063 commit ce550ca. Next action: verify official OpenAI hosted web_search request and response shapes, then add focused proxy characterisation tests before implementation. No blocker.

2026-08-21: Official OpenAI tools guidance and Responses API reference confirm tools:[{type:web_search}], model-controlled selection when tool_choice is not forced, typed web_search_call output items, final message output_text extraction, and max_tool_calls as the total hosted-tool-call ceiling. Selected max_tool_calls:1 with query/source/result-free diagnostics.

2026-08-21 focused verification: OpenAiServiceTest 15, FactControllerTest 25 and OpenApiContractTest 2 passed with 0 failures (42 proxy tests total). Evidence covers model-controlled tools:[{type:web_search}], max_tool_calls:1, preserved GPT-5.6 Sol medium/RH-063 linkage and compaction/4096 ceiling/completed-status rejection/sanitisation/no recent-place list, searched and unsearched response shapes, final-message output_text-only extraction, privacy-safe zero/one-call diagnostics, stable timeout/provider/tool classifications, and the existing retryable 502 base-place fallback. Diff review and git diff --check found no issue. No iOS tests, full proxy suite, live OpenAI call, merge, deployment or device work was performed.

2026-08-21 branch hand-off: implementation commit 96c5343 was verified through the GH-PERSONAL capability check and dry-run, then pushed to origin/codex/rh-028-web-search. No pull request, merge or deployment was performed. Status remains In Progress because integration and independent review are outstanding.

2026-08-21 independent review reopened AC #2 and #3. P1 requires visible clickable attribution for web-derived facts; P2 requires completed final_answer selection with phase-less compatibility; P3 requires explicit openai_result field/privacy documentation. RH-063 advanced to 919644a only through a merged RH-062 history commit plus LocationManagerTests and ledger evidence; no production dependency contract changed, so RH-028 retains its existing ce550ca RH-063 production base rather than importing unrelated task evidence.
<!-- SECTION:NOTES:END -->

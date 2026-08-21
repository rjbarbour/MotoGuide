---
id: RH-028
title: Web-search-enabled place facts
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-17 22:42'
updated_date: '2026-08-21 11:46'
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

Scope: proxy Responses request construction; completed final-answer selection; canonical bounded url_citation extraction and deduplication; structured fail-closed fact-source contract; source propagation through generation, cache and existing Log display; clickable visual attribution that never enters announcement text or TTS; bounded failure/cost diagnostics and fallback classification; focused changed proxy and Swift simulator tests; and necessary OpenAPI, implementation-contract and privacy wording.

Exclusions: no recent-place list, no change to GPT-5.6 Sol medium, no spoken citation text, no general Log redesign, no deployment, merge or device build.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Responses request exposes model-controlled hosted web_search.
- [ ] #2 Searched and unsearched outputs satisfy the existing ride-safe text and privacy contract.
- [x] #3 Timeout, provider failure and tool-cost diagnostics and fallback remain bounded and tested.
- [ ] #4 Web-derived facts return bounded structured sources parsed from final-response url_citation annotations, and the existing RideHorizon Log displays those sources as clearly visible clickable links without adding citation titles or URLs to announcement text or TTS.
- [ ] #5 Any generated fact that can later be displayed carries its sources through the app pipeline and cache; otherwise that web-derived fact is not cached.
- [x] #6 When message phase is present, only a completed final_answer message is accepted; a completed phase-less message remains compatible, while commentary and incomplete message paths are rejected.
- [x] #7 openai_result and its diagnostics-only fields are documented as bounded and privacy-safe, excluding search queries, results, sources, place text and rider text.
- [ ] #8 Citation URLs are canonicalised before validation; HTTPS is checked case-insensitively on the canonical URI, the final ASCII URL is at most 2048 characters, and deduplication uses that canonical URL so Unicode expansion cannot break iOS attribution.
- [ ] #9 The iOS fact response requires a sources field and fails closed when it is missing or any provided source is malformed; an uncited response is valid only with an explicit empty sources array.
- [ ] #10 Every success example in FACT_PROXY_CONTRACT.md includes the required sources field, either empty or populated with bounded cited sources.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Preserve all completed RH-028 behaviour and RH-063 linkage/compaction boundaries.
2. Add focused Java regressions proving URL canonicalisation precedes case-insensitive HTTPS validation, final ASCII length enforcement and canonical deduplication, including Unicode expansion beyond 2048.
3. Add focused Swift regressions for missing sources, malformed provided sources, explicit empty sources and canonical cited sources.
4. Implement proxy canonicalisation/bounding and make FactProxyResponse.sources required with all-or-nothing source validation on iOS.
5. Correct every stale FACT_PROXY_CONTRACT.md success response example and keep OpenAPI wording synchronised if necessary.
6. Run only the focused changed proxy tests and focused Swift simulator suites, then perform the bounded two-axis review.
7. Record evidence, commit and push RH-028, clean generated output, and leave the worktree clean without merge or deployment.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-21: Claimed on branch codex/rh-028-web-search from RH-063 commit ce550ca. Next action: verify official OpenAI hosted web_search request and response shapes, then add focused proxy characterisation tests before implementation. No blocker.

2026-08-21: Official OpenAI tools guidance and Responses API reference confirm tools:[{type:web_search}], model-controlled selection when tool_choice is not forced, typed web_search_call output items, final message output_text extraction, and max_tool_calls as the total hosted-tool-call ceiling. Selected max_tool_calls:1 with query/source/result-free diagnostics.

2026-08-21 focused verification: OpenAiServiceTest 15, FactControllerTest 25 and OpenApiContractTest 2 passed with 0 failures (42 proxy tests total). Evidence covers model-controlled tools:[{type:web_search}], max_tool_calls:1, preserved GPT-5.6 Sol medium/RH-063 linkage and compaction/4096 ceiling/completed-status rejection/sanitisation/no recent-place list, searched and unsearched response shapes, final-message output_text-only extraction, privacy-safe zero/one-call diagnostics, stable timeout/provider/tool classifications, and the existing retryable 502 base-place fallback. Diff review and git diff --check found no issue. No iOS tests, full proxy suite, live OpenAI call, merge, deployment or device work was performed.

2026-08-21 branch hand-off: implementation commit 96c5343 was verified through the GH-PERSONAL capability check and dry-run, then pushed to origin/codex/rh-028-web-search. No pull request, merge or deployment was performed. Status remains In Progress because integration and independent review are outstanding.

2026-08-21 independent review reopened AC #2 and #3. P1 requires visible clickable attribution for web-derived facts; P2 requires completed final_answer selection with phase-less compatibility; P3 requires explicit openai_result field/privacy documentation. RH-063 advanced to 919644a only through a merged RH-062 history commit plus LocationManagerTests and ledger evidence; no production dependency contract changed, so RH-028 retains its existing ce550ca RH-063 production base rather than importing unrelated task evidence.

2026-08-21 independent-review remediation evidence: OpenAiServiceTest 21, FactControllerTest 26, SharedContractFixtureTest 2 and OpenApiContractTest 2 passed with 0 failures (51 focused proxy tests). Focused iPhone 17 / iOS 26.3.1 simulator testing passed RideLogSourceLinkTests 1, CachedPlaceFactGeneratorTests 4, ProxyFactGeneratorTests 30, AnnouncementCoordinatorTests 26 and LocationManagerTests 84 with 0 failures (145 focused Swift tests). Evidence proves bounded unique HTTPS url_citation parsing, required attribution for searched output, completed final_answer selection with phase-less compatibility, commentary/incomplete rejection, structured source transport, sourced-fact cache bypass, exact clickable Log destination, preservation through queue/LocationManager, and exclusion from announcement/TTS text. The first end-to-end Log callback run exposed a test-helper address-state gap; the helper was corrected and the final focused run passed. No full suite, device build, device install, live OpenAI call, merge or deployment was performed.

2026-08-21 two-axis review of git diff 677a41d...HEAD initially found stale human-contract response/event sections, an over-broad source-title overlap rejection and missing direct Log-link destination evidence. Commits 8e97c3e and 9f3e82a resolve them. Follow-up Standards and Specification reviews both returned zero remaining findings. RH-063 linkage/compaction, max_output_tokens:4096 and the no-recent-place-list boundary remain unchanged.

2026-08-21 final branch hand-off: commits 8e97c3e, 9f3e82a and d7a8a26 were pushed to origin/codex/rh-028-web-search. No pull request, merge, deployment, device build or device install was performed. Status remains In Progress because canonical integration is intentionally outstanding.

2026-08-21 final findings reopened AC #2, #4 and #5. F-01 requires canonical ASCII URL validation/deduplication before the 2048 limit; F-02 requires iOS sources to be present and strictly all-or-nothing valid, with [] as the only uncited representation; F-03 identifies a remaining stale success example in the human contract. No product, model, ride-state or spoken-output scope changes are authorised.
<!-- SECTION:NOTES:END -->

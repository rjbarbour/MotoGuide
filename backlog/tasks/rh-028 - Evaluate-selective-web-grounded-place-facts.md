---
id: RH-028
title: Web-search-enabled place facts
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-17 22:42'
updated_date: '2026-08-21 10:59'
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
priority: high
type: feature
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Offer OpenAI hosted web search as a model-controlled tool for ride-safe place-fact generation on top of RH-063, while preserving application-owned ride linkage and compaction, output limits, response validation, sanitisation and privacy boundaries.

Scope: proxy Responses request construction, final output extraction, bounded failure/cost diagnostics and fallback classification, focused proxy tests, and only necessary OpenAPI/contract/privacy wording.

Exclusions: no recent-place list, no change to the GPT-5.6 Sol medium model policy, no app feature expansion, deployment or merge.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Responses request exposes model-controlled hosted web_search.
- [x] #2 Searched and unsearched outputs satisfy the existing ride-safe text and privacy contract.
- [x] #3 Timeout, provider failure and tool-cost diagnostics and fallback remain bounded and tested.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify the hosted web_search Responses API request and output-item shapes against current official OpenAI documentation.
2. Characterise the RH-063 proxy request, final-text extraction, diagnostics, fallback and privacy boundaries with focused tests.
3. Offer hosted web_search without changing the pinned model/reasoning, app-owned ride linkage/compaction, 4,096 ceiling, completed-status rejection, sanitisation or no-recent-place-list boundary.
4. Tolerate tool-call output items while extracting only final output_text; keep provider/tool failure and cost diagnostics bounded.
5. Update only necessary OpenAPI, implementation-contract and privacy wording.
6. Run focused proxy tests, record evidence, commit and push RH-028, then leave the worktree clean without merging or deploying.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-21: Claimed on branch codex/rh-028-web-search from RH-063 commit ce550ca. Next action: verify official OpenAI hosted web_search request and response shapes, then add focused proxy characterisation tests before implementation. No blocker.

2026-08-21: Official OpenAI tools guidance and Responses API reference confirm tools:[{type:web_search}], model-controlled selection when tool_choice is not forced, typed web_search_call output items, final message output_text extraction, and max_tool_calls as the total hosted-tool-call ceiling. Selected max_tool_calls:1 with query/source/result-free diagnostics.

2026-08-21 focused verification: OpenAiServiceTest 15, FactControllerTest 25 and OpenApiContractTest 2 passed with 0 failures (42 proxy tests total). Evidence covers model-controlled tools:[{type:web_search}], max_tool_calls:1, preserved GPT-5.6 Sol medium/RH-063 linkage and compaction/4096 ceiling/completed-status rejection/sanitisation/no recent-place list, searched and unsearched response shapes, final-message output_text-only extraction, privacy-safe zero/one-call diagnostics, stable timeout/provider/tool classifications, and the existing retryable 502 base-place fallback. Diff review and git diff --check found no issue. No iOS tests, full proxy suite, live OpenAI call, merge, deployment or device work was performed.

2026-08-21 branch hand-off: implementation commit 96c5343 was verified through the GH-PERSONAL capability check and dry-run, then pushed to origin/codex/rh-028-web-search. No pull request, merge or deployment was performed. Status remains In Progress because integration and independent review are outstanding.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented RH-028 on top of RH-063 by offering model-controlled hosted web_search with a one-call ceiling, accepting searched or unsearched completed Responses output while extracting only final message output_text, and preserving all existing ride-state, output, sanitisation and privacy boundaries. Added bounded search-call diagnostics and stable timeout/provider/tool fallback classification; updated only the necessary OpenAPI, proxy-contract and privacy wording. Verified 42 focused proxy tests with zero failures. Branch remains In Progress and unmerged as requested.
<!-- SECTION:FINAL_SUMMARY:END -->

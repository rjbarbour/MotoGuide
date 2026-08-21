---
id: RH-062
title: Upgrade place-fact generation to GPT-5.6 Sol with medium reasoning
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-21 10:39'
labels:
  - core
  - model
  - proxy
milestone: m-1
dependencies: []
references:
  - 'https://developers.openai.com/api/docs/models/gpt-5.6-sol'
  - 'https://developers.openai.com/api/docs/guides/upgrading-to-gpt-5p6-sol'
modified_files:
  - FACT_PROXY_OPENAPI.yaml
  - docs/architecture/contracts/FACT_PROXY_CONTRACT.md
  - docs/research/2026-08-04-sar-erasure-operations.md
  - fact-proxy/README.md
  - fact-proxy/fly.toml
  - >-
    fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/FactMode.java
  - >-
    fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/OpenAiService.java
  - fact-proxy/src/main/resources/application.yml
  - >-
    fact-proxy/src/test/java/ai/digitalmercenaries/ridehorizon/factproxy/OpenAiServiceTest.java
  - >-
    fact-proxy/src/test/java/ai/digitalmercenaries/ridehorizon/factproxy/OpenApiContractTest.java
priority: high
type: enhancement
ordinal: 114000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Upgrade the production place-fact path from gpt-4o-mini Chat Completions to GPT-5.6 Sol with medium reasoning through the Responses API. Preserve existing ride-safe prompting, sanitisation, timeouts, consent and fallback behaviour.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The proxy requests GPT-5.6 Sol with medium reasoning through a supported OpenAI API configuration
- [ ] #2 Representative UK place-fact evaluations compare factuality, repetition, relevance, latency and token cost against the current production baseline
- [ ] #3 Timeout, sanitisation, fallback, consent and privacy behaviour remain bounded and tested
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Keep the branch limited to RH-062 and preserve current main.
2. Send stateless Responses requests to /v1/responses with model gpt-5.6-sol, reasoning.effort medium, store false and max_output_tokens 4096 for 35–90-word place facts.
3. Accept output only when the top-level Responses status is completed; reject incomplete or other non-completed output before sanitisation.
4. Reconcile OpenAPI, architecture contract and SAR documentation: merging to main intentionally deploys the private-beta candidate; store false disables stored Response objects but does not remove prompt caching of encrypted tensors for up to 24 hours or default abuse-monitoring logs for up to 30 days.
5. Run only OpenAiServiceTest and OpenApiContractTest, record exact evidence, commit one RH-062 correction and force-with-lease push.
6. Do not merge or deploy; keep RH-062 In Progress until representative UK factuality, repetition, relevance, latency and token-cost evaluation completes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner-authorised execution on 2026-08-21 is limited to RH-062 on branch codex/rh-062-openai-ride-session. Explicit exclusions: previous_response_id and conversation compaction remain RH-063; web_search remains RH-028; no push, merge, deploy, secrets changes or iOS tests. The earlier combined-batch note is superseded for this isolated implementation.

Focused verification on 2026-08-21: ./gradlew test --tests ai.digitalmercenaries.ridehorizon.factproxy.OpenAiServiceTest --console=plain completed BUILD SUCCESSFUL in 11s. JUnit result: 5 tests, 0 failures, 0 errors, 0 skipped. Coverage proves /v1/responses, gpt-5.6-sol, reasoning effort medium, existing prompt and mode token budgets, typed output_text parsing, HTTP 429 classification and unusable-output sanitisation failure. No live OpenAI request, previous_response_id, conversation compaction, web_search, secret change, deploy or iOS test was performed. Acceptance criterion 2 remains open for representative UK live evaluations; acceptance criterion 3 remains open for the wider combined behaviour evidence.

Independent review remediation started on 2026-08-21. The pre-existing branch included one mixed ledger commit affecting RH-024, RH-028 and RH-063; local branch history was reset softly to current main e95db355 and those three non-RH-062 task files were restored exactly from main. Main was not modified.

The 2026-08-21 continuation instruction supersedes the earlier no-push boundary: push this RH-062-only branch, but do not merge or deploy. Review remediation now sends store:false, requires top-level status completed, uses a 25,000 max_output_tokens calibration ceiling that includes reasoning, and reconciles the OpenAPI, architecture contract and SAR documentation while distinguishing candidate configuration from the last documented deployment. Focused verification: ./gradlew test --tests ai.digitalmercenaries.ridehorizon.factproxy.OpenAiServiceTest --tests ai.digitalmercenaries.ridehorizon.factproxy.OpenApiContractTest --console=plain completed BUILD SUCCESSFUL in 2s. JUnit: OpenAiServiceTest 6 tests and OpenApiContractTest 2 tests; total 8, failures 0, errors 0, skipped 0. The deployment and representative UK factuality, repetition, relevance, latency and token-cost evaluation gate remains open; RH-062 stays In Progress.

Second independent review started on 2026-08-21. Official OpenAI documentation confirms max_output_tokens includes reasoning and visible output but provides no smaller workload-specific safe ceiling; owner selected 4,096 for bounded 35–90-word facts. Prior notes saying deployment waits for evaluation and treating store:false as the whole retention picture are superseded.

Second-review correction verified on 2026-08-21: max_output_tokens is 4,096 for both fact modes; non-completed Responses remain rejected before output parsing; OpenAPI and architecture wording now state that merging to main intentionally deploys the private-beta candidate; SAR wording distinguishes no stored Response object under store:false from encrypted prompt-cache tensors retained for up to 24 hours and default abuse-monitoring logs retained for up to 30 days. Focused command ./gradlew test --tests ai.digitalmercenaries.ridehorizon.factproxy.OpenAiServiceTest --tests ai.digitalmercenaries.ridehorizon.factproxy.OpenApiContractTest --console=plain completed BUILD SUCCESSFUL in 3s. JUnit: 8 tests total, 0 failures, 0 errors, 0 skipped. No merge, deployment or iOS test was performed. Representative UK quality, latency and cost evaluation remains open and RH-062 stays In Progress.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @codex
created: 2026-08-21 10:28
---
Independent review code and documentation findings are resolved with focused evidence. Deployment and representative live evaluation remain explicitly open.
---

author: @codex
created: 2026-08-21 10:39
---
Second independent review findings are resolved with focused proxy evidence. Merge/deployment was not performed; post-deployment representative UK evaluation remains open.
---
<!-- COMMENTS:END -->

---
id: RH-065
title: Make Long Facts materially longer
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-21 12:15'
labels:
  - core
  - facts
  - speech
milestone: m-1
dependencies:
  - RH-028
modified_files:
  - FACT_PROXY_OPENAPI.yaml
  - RideHorizonTests/RideHorizonTests.swift
  - docs/architecture/contracts/FACT_PROXY_CONTRACT.md
  - >-
    fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/FactMode.java
  - >-
    fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/OpenAiService.java
  - >-
    fact-proxy/src/test/java/ai/digitalmercenaries/ridehorizon/factproxy/FactSanitizerTest.java
  - >-
    fact-proxy/src/test/java/ai/digitalmercenaries/ridehorizon/factproxy/OpenAiServiceTest.java
  - >-
    fact-proxy/src/test/java/ai/digitalmercenaries/ridehorizon/factproxy/OpenApiContractTest.java
priority: medium
type: enhancement
ordinal: 117000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Increase the opt-in Long Facts content depth from the current 75–90 words to an initial 110–130-word target while keeping the result coherent, factual and subordinate to navigation audio.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Long Facts consistently target 110–130 words without padding, trivia-list structure or repeated context
- [x] #2 Short Facts and Names Only behaviour remain unchanged
- [ ] #3 Moving and stationary listening checks record duration, intelligibility and navigation-audio interruption behaviour before the new target is accepted
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add focused proxy tests that pin Long Facts to a 110–130-word coherent response instruction and updated sentence bound while asserting the Short Facts prompt, GPT-5.6 Sol medium, web search and 4,096-token ceiling remain unchanged.
2. Update only the Long Facts mode and fallback prompts, plus the proxy sentence bound needed for the longer coherent response; retain existing sanitisation, fallback and app-compatible 1,500-character limit unless focused evidence requires a change.
3. Add focused Swift regression evidence for unchanged Short Facts and Names Only mode mapping and the existing Long Facts app-side bound; do not change speech sequencing or interruption behaviour.
4. Synchronise only necessary contract wording for the 110–130-word Long Facts target and deterministic sentence bound; do not change privacy wording unless data handling changes.
5. Run only focused changed proxy tests and focused simulator tests, review the diff, record evidence while leaving acceptance criterion 3 open for later physical moving/stationary listening, then commit and push RH-065 without merge, deploy or device build.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-21: Claimed on branch codex/rh-065-long-facts stacked at RH-028 web-search commit 5e66cfb. Dependency updated to RH-028 so the ledger matches the authorised stack. Acceptance criterion 3 remains a later physical moving/stationary listening gate; no merge, deployment or device build is authorised.

2026-08-21 focused verification: 16 proxy tests passed with 0 failures across FactSanitizerTest, three targeted OpenAiServiceTest cases and OpenApiContractTest. Evidence covers the 110–130-word coherent Long Facts instruction, no trivia-list/repeated-context/padding instruction, exact five-sentence acceptance and six-sentence rejection, unchanged 35–45-word Short Facts bounds, GPT-5.6 Sol medium, model-controlled web search, per-ride previous-response linkage and compaction, and the 4,096 output ceiling. Focused iPhone 17 / iOS 26.3.1 simulator testing passed RideHorizonTests and FactPhraseBuilderTests: 9 tests, 0 failures, proving unchanged Short Facts and Names Only routing plus the compatible 1,500-character Long Facts app bound. Standards and Specification follow-up reviews found zero remaining findings. Privacy wording was unchanged because data handling did not change. No full suite, device build, device install, deployment or merge was performed. Acceptance criterion 3 remains open pending physical moving/stationary listening evidence.

2026-08-21 branch hand-off: implementation commit a588981 passed the GH-PERSONAL capability check and exact-branch dry run, then pushed to origin/codex/rh-065-long-facts. Next gate: review/integration coordination followed by acceptance criterion 3 physical moving/stationary duration, intelligibility and navigation-audio interruption evidence. Status remains In Progress. No pull request, merge, deployment, device build or device install was performed.

2026-08-21 dependency rebase evidence: this supersedes the earlier 5e66cfb/a588981/717b638 branch hand-off. RH-065 — Make Long Facts materially longer was rebased exactly from old base 5e66cfb onto final RH-028 — Web-search-enabled place facts commit e3a76c9, replaying only the two RH-065 commits. The sole conflict was the OpenAPI checksum; resolution preserved RH-028 canonical-ASCII HTTPS citation validation, final-length enforcement, deduplication and fail-closed source behaviour together with the RH-065 Long Facts contract, producing verified SHA-256 449b0bb0d09c83374547e47bac6e6e0fe0e165951aa9e95778dea5d136753d8c. Post-rebase focused verification passed the same 16 proxy tests and 9 iPhone 17 / iOS 26.3.1 simulator tests with zero failures. No other tests, merge, deployment, device build or device install were performed. Acceptance criterion 3 remains open.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
RH-065 — Make Long Facts materially longer is rebased onto final RH-028 — Web-search-enabled place facts commit e3a76c9 with exactly the two RH-065 commits replayed. The combined contract preserves RH-028 fail-closed canonical citation/source handling and RH-065's 110–130-word coherent Long Facts target, with verified OpenAPI SHA-256 449b0bb0d09c83374547e47bac6e6e0fe0e165951aa9e95778dea5d136753d8c. Post-rebase focused evidence passed 16 proxy and 9 simulator tests with zero failures. Acceptance criterion 3 remains open for later physical moving/stationary listening evidence.
<!-- SECTION:FINAL_SUMMARY:END -->

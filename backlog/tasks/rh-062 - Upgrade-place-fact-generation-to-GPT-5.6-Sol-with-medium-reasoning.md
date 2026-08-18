---
id: RH-062
title: Upgrade place-fact generation to GPT-5.6 Sol with medium reasoning
status: To Do
assignee: []
created_date: '2026-08-18 12:58'
labels:
  - core
  - model
  - proxy
milestone: m-1
dependencies: []
references:
  - 'https://developers.openai.com/api/docs/models/gpt-5.6-sol'
priority: medium
type: enhancement
ordinal: 114000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Keep OpenAI as the place-fact provider and evaluate GPT-5.6 Sol with medium reasoning as the quality-first production model. Make model and reasoning configuration explicit and verify that the improvement is acceptable for ride-time latency, cost, safety and fallback behaviour.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The proxy requests GPT-5.6 Sol with medium reasoning through a supported OpenAI API configuration
- [ ] #2 Representative UK place-fact evaluations compare factuality, repetition, relevance, latency and token cost against the current production baseline
- [ ] #3 Timeout, sanitisation, fallback, consent and privacy behaviour remain bounded and tested
<!-- AC:END -->

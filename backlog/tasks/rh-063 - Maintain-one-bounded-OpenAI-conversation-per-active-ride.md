---
id: RH-063
title: Maintain one bounded OpenAI conversation per active ride
status: To Do
assignee: []
created_date: '2026-08-18 12:58'
labels:
  - core
  - model
  - session
milestone: m-1
dependencies:
  - RH-062
references:
  - 'https://developers.openai.com/api/docs/guides/latest-model'
priority: medium
type: feature
ordinal: 115000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Use the OpenAI Responses API to continue one bounded model conversation during an active ride so successive place facts share immediate context. Application-owned ride context remains authoritative; provider conversation state is an aid, not the only memory or recovery mechanism.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The first eligible fact request in a ride establishes a conversation and later requests continue it through supported Responses API linkage
- [ ] #2 End ride clears active provider-conversation linkage and a new ride starts independently
- [ ] #3 Expired, missing or failed provider state rebuilds safely from bounded application-owned ride context without duplicating delivered facts
<!-- AC:END -->

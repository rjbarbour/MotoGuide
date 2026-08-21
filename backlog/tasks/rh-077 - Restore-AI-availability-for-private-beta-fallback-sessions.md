---
id: RH-077
title: Restore AI availability for private-beta fallback sessions
status: Done
assignee:
  - '@codex'
created_date: '2026-08-21 11:36'
updated_date: '2026-08-21 11:43'
labels:
  - proxy
  - ai
  - reliability
dependencies: []
references:
  - 'https://github.com/rjbarbour/MotoGuide/pull/54'
  - 'https://github.com/rjbarbour/MotoGuide/actions/runs/32478371230'
modified_files:
  - >-
    fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/JdbcSessionAuthority.java
  - fact-proxy/src/main/resources/application.yml
  - >-
    fact-proxy/src/test/java/ai/digitalmercenaries/ridehorizon/factproxy/PrivateBetaFallbackQuotaHttpTest.java
priority: high
type: bug
ordinal: 215000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The live private beta uses fallback sessions because App Attest is not enabled. Production fallback quotas are 20 facts and 12,000 speech characters per installation per day; the active tester reached both caps and every valid AI request then returned HTTP 429 before OpenAI. Raise the private-beta fallback allowance to the existing verified-session allowance without weakening global caps, authentication or privacy controls.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A production-default fallback session can complete at least 21 fact requests in one day without receiving HTTP 429.
- [x] #2 Fallback fact and speech allowances match the existing verified-session private-beta allowances while global caps remain unchanged.
- [x] #3 The focused proxy regression tests pass and the corrected proxy is deployed with live requests no longer rejected at the old fallback cap.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a production-default HTTP regression that fails on the 21st fallback fact request. 2. Raise only the fallback per-installation defaults to the existing verified-session values and keep global limits unchanged. 3. Run focused automatic-session and quota tests, then the proxy suite. 4. Commit, push, review, merge and verify the live proxy no longer rejects at the old cap.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Red evidence: PrivateBetaFallbackQuotaHttpTest failed deterministically on request 21 with the production fallback default. Live Fly logs showed repeated HTTP 429 rate_limit before OpenAI, and aggregate PostgreSQL counters were exactly 20 facts and 11,998 of 12,000 speech characters for one fallback subject while global fact usage was only 20 of 2,000. Fix raises fallback defaults to the existing verified-session allowances: 180 facts and 120,000 speech characters; global caps are unchanged. Focused automatic-session/quota tests and the complete proxy suite both passed with BUILD SUCCESSFUL.

PR #54 merged to main at 88c59fa. Post-merge main tests passed; canonical proxy deployment run 32478371230 deployed that exact commit and its health smoke check passed. A read-only runtime check confirmed no Fly environment overrides mask the new fallback or global quota defaults.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Restored private-beta AI availability by raising fallback per-installation quotas from 20 facts and 12,000 speech characters to the existing verified-session allowances of 180 and 120,000. The request-21 HTTP regression, focused tests, full proxy suite, post-merge tests, production deployment and health smoke check passed; global caps remain unchanged.
<!-- SECTION:FINAL_SUMMARY:END -->

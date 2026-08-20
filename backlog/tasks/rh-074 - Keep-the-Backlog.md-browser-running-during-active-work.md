---
id: RH-074
title: Keep the Backlog.md browser running during active work
status: Done
assignee:
  - '@codex'
created_date: '2026-08-20 09:29'
updated_date: '2026-08-20 09:29'
labels: []
dependencies: []
modified_files:
  - AGENTS.md
priority: low
type: docs
ordinal: 210000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Make the RideHorizon Backlog.md browser a standing project runtime so agents do not wait for an owner prompt or rediscover its launch procedure.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 AGENTS.md requires the browser on 127.0.0.1:6420 during active project work
- [x] #2 AGENTS.md preserves the exact launch command and requires immediate host execution rather than a sandbox attempt
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Add one concise runtime section to AGENTS.md, verify the exact command text and documentation diff, then integrate without builds or product tests.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified the exact launch command appears in AGENTS.md and git diff --check passes. No builds or tests were run.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added the standing RideHorizon runtime rule to keep Backlog.md available on port 6420 and launch it directly with host permission when absent.
<!-- SECTION:FINAL_SUMMARY:END -->

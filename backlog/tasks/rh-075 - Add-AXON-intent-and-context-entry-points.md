---
id: RH-075
title: Add AXON intent and context entry points
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-20 10:55'
updated_date: '2026-08-20 11:04'
labels:
  - axon
  - control-plane
  - documentation
dependencies: []
references:
  - 'https://github.com/rjbarbour/MotoGuide/pull/44'
priority: medium
type: docs
ordinal: 211000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create concise root INTENT.md and CONTEXT.md authorities from the accepted RideHorizon product definition and repository control plane. Route existing entry points to them without duplicating live delivery state, detailed procedures or speculative roadmap commitments.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 INTENT.md defines the enduring purpose, first user, canonical use case, MVP boundary, optional future direction, non-goals and decision principles without live task status
- [ ] #2 CONTEXT.md provides a concise project and architecture summary, intent anchor, authority map, resolved domain language, positive procedure triggers and an explicit Tier 3 position without duplicating AGENTS.md
- [ ] #3 README.md and AGENTS.md route readers and agents to both files while preserving one source of truth per concern
- [ ] #4 All links resolve, git diff --check passes and an independent intent review finds no material conflict with accepted project authority
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Read the bounded intent, state, roadmap, documentation-map and decision sources. 2. Draft concise INTENT.md and CONTEXT.md with non-overlapping authority. 3. Add only minimal README.md and AGENTS.md routes. 4. Verify headings, links, duplication and Git diff; obtain one independent intent/standards review. 5. Integrate through one PR, close, clean and stop.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Created concise root INTENT.md and CONTEXT.md from the accepted ICB, AGENTS.md product definition, MILESTONES.md capability ladder, PROJECT.md state boundary, documentation map and accepted decision catalogue. INTENT.md owns enduring purpose and trade-offs; CONTEXT.md owns authority, architecture/language and positive procedure routing. README.md and AGENTS.md received links only. Structural evidence: every relative link resolves, git diff --check passes and test selection correctly chooses no application suite.

Independent intent review found two narrow issues: CONTEXT.md over-triggered the Git SOP for trivial file edits, and README.md still described RideHorizon primarily as an audio companion. Corrections restore the substantive-change threshold and describe the visual geographic-awareness core with optional audio.

Final independent re-review of exact head 4b58796 reports zero findings.
<!-- SECTION:NOTES:END -->

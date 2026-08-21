---
id: RH-066
title: Expose all installed English Apple voices and choose a distinct default
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-21 11:00'
labels:
  - core
  - apple-voice
  - settings
milestone: m-1
dependencies: []
references:
  - 'https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice'
modified_files:
  - RideHorizon/LocationManager.swift
  - RideHorizonTests/LocationManagerTests.swift
  - RideHorizonTests/RideSettingsStoreTests.swift
priority: medium
type: enhancement
ordinal: 118000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remove RideHorizon’s artificial four-voice limit, let the rider preview every suitable installed English Apple system voice, and choose a default that is recognisably distinct from Calimoto and the disliked Eddy voice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The picker exposes all suitable English voices returned as available on the device rather than stopping after four
- [x] #2 Each option identifies voice name, English locale and quality clearly enough to compare choices
- [x] #3 Preview and persisted selection work for every exposed voice, with a safe fallback when a selected voice is removed or unavailable
- [ ] #4 The production default is selected through owner listening evidence and is distinct from Calimoto and Eddy
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a deterministic Apple voice catalogue policy that keeps every valid installed English voice, de-duplicates identifiers, orders British and higher-quality options predictably, and produces name, locale and quality labels.
2. Make Serena the provisional named high-quality preference when installed; otherwise choose the best high-quality English non-Eddy/Eddie option, with a safe deterministic fallback if a persisted selection disappears.
3. Route picker, recommendation, preview and normal Apple speech through the validated selection while preserving explicit rider choices in RideSettings.
4. Add focused deterministic tests for filtering, de-duplication, ordering, labels, provisional-default exclusions, missing-selection fallback and persisted identifier round trips.
5. Run only the focused simulator tests for the changed voice/settings logic, record evidence while leaving acceptance criterion 4 open for owner listening, then commit and push RH-066 with a clean worktree.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented an uncapped deterministic catalogue for all valid installed English Apple voices, with stable British/quality/name ordering and name · locale · quality labels. Serena is the provisional high-quality automatic preference when installed; fallback excludes Eddy/Eddie from automatic selection but preserves an explicit rider choice. Missing persisted voices are replaced by the current safe provisional selection, and preview always routes through Apple TTS.
Verification on 2026-08-21: focused iPhone 17 / iOS 26.3.1 simulator invocation ran 7 selected voice/settings tests with 0 failures. The full suite, physical-device build, installation, deployment and merge were deliberately not run. Acceptance criterion 4 remains open pending owner listening on the physical iPhone before the production default is selected.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @codex
created: 2026-08-21 11:00
---
Implementation and focused automated evidence are ready. Owner action remains: listen to the provisional Serena choice and alternatives on the physical iPhone before accepting criterion 4 or selecting the production default.
---
<!-- COMMENTS:END -->

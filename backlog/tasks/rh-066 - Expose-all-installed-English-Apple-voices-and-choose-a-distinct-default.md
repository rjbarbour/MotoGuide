---
id: RH-066
title: Expose all installed English Apple voices and choose a distinct default
status: In Progress
assignee:
  - '@codex'
created_date: '2026-08-18 12:58'
updated_date: '2026-08-21 11:57'
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
  - RideHorizonTests/PlaceFactTests.swift
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

6. Address review findings by capturing SpeechVoiceSelection in the speech-output test double and injecting deterministic voice options into LocationManager tests so persisted, provisional and missing-selection fallback identifiers are asserted through Preview and normal Apple speech.
7. Make catalogue de-duplication input-order independent and replace locale-sensitive comparisons with fixed POSIX-normalised keys; add a reversed-input conflicting-duplicate regression test.
8. Re-run only the focused voice/settings simulator tests, retain acceptance criterion 3 only on passing end-to-end evidence, record the review fix, commit once as RH-066, and push clean while criterion 4 remains open.

9. Fix PR #53’s CI-only timing failure without product changes: add request/end callbacks to MockPlaceFactGenerator and replace fixed sleeps in testActiveRideIdentityBoundsFactRequestsAndEndConversation with XCTest expectations tied to the recorded request and end-conversation linkage.
10. Run only that one test twice, record both passes, commit once as test(RH-066), push the branch clean, and leave PR #53 unmerged.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented an uncapped deterministic catalogue for all valid installed English Apple voices, with stable British/quality/name ordering and name · locale · quality labels. Serena is the provisional high-quality automatic preference when installed; fallback excludes Eddy/Eddie from automatic selection but preserves an explicit rider choice. Missing persisted voices are replaced by the current safe provisional selection, and preview always routes through Apple TTS.
Verification on 2026-08-21: focused iPhone 17 / iOS 26.3.1 simulator invocation ran 7 selected voice/settings tests with 0 failures. The full suite, physical-device build, installation, deployment and merge were deliberately not run. Acceptance criterion 4 remains open pending owner listening on the physical iPhone before the production default is selected.

2026-08-21 review follow-up: two independent findings accepted within RH-066 scope—end-to-end selected identifier evidence and deterministic duplicate resolution/sorting.

Acceptance criterion 3 temporarily reopened pending the requested exact identifier propagation tests.

Review findings resolved. RecordingSpeechOutputEngine now captures SpeechVoiceSelection. Deterministic injected voice catalogues prove that the exact persisted, provisional Serena and missing-selection fallback identifiers each reach both Preview and normal Apple speech. Catalogue entries are sorted before de-duplication with fixed en_US_POSIX-normalised comparison keys and raw-value tie-breakers, so conflicting duplicate metadata resolves identically for forward and reversed input.
Focused verification on 2026-08-21: 10 selected voice/settings tests passed, 0 failed, 0 skipped on iPhone 17 / iOS 26.3.1 simulator. No full suite, device build, deployment or merge was run. Acceptance criterion 3 is re-checked from this evidence; criterion 4 remains open for owner listening.

PR #53 CI follow-up: full-suite failure was isolated to testActiveRideIdentityBoundsFactRequestsAndEndConversation timing out its fixed 100 ms sleep during CI voice-database startup; product behaviour was not implicated.

CI timing fix implemented without product changes. MockPlaceFactGenerator now exposes optional callbacks after appending a fact request and after recording endRideConversation. testActiveRideIdentityBoundsFactRequestsAndEndConversation waits for those XCTest expectations before reading the ride ID and asserting end linkage; the fixed 100 ms and 50 ms sleeps are removed.
Focused verification on 2026-08-21: the single test passed twice independently on iPhone 17 / iOS 26.3.1 simulator; each completed result bundle reports exactly 1 passed, 0 failed and 0 skipped. One earlier invocation ended during simulator test-host bootstrap before XCTest ran and is not counted as test evidence. No other tests, product build, device build, deployment or merge were run.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @codex
created: 2026-08-21 11:00
---
Implementation and focused automated evidence are ready. Owner action remains: listen to the provisional Serena choice and alternatives on the physical iPhone before accepting criterion 4 or selecting the production default.
---

author: @codex
created: 2026-08-21 11:14
---
Both independent RH-066 review findings are resolved with focused automated evidence; criterion 4 remains open for physical-iPhone owner listening.
---

author: @codex
created: 2026-08-21 11:57
---
PR #53 CI-only timing fix is ready: the formerly flaky test passed twice using event-driven expectations; product code is unchanged.
---
<!-- COMMENTS:END -->

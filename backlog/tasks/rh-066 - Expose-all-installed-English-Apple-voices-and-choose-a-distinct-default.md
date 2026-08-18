---
id: RH-066
title: Expose all installed English Apple voices and choose a distinct default
status: To Do
assignee: []
created_date: '2026-08-18 12:58'
labels:
  - core
  - apple-voice
  - settings
milestone: m-1
dependencies: []
references:
  - 'https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice'
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
- [ ] #1 The picker exposes all suitable English voices returned as available on the device rather than stopping after four
- [ ] #2 Each option identifies voice name, English locale and quality clearly enough to compare choices
- [ ] #3 Preview and persisted selection work for every exposed voice, with a safe fallback when a selected voice is removed or unavailable
- [ ] #4 The production default is selected through owner listening evidence and is distinct from Calimoto and Eddy
<!-- AC:END -->

# Milestone 1 Status

Date: 2026-07-01

## Result

Milestone 1 is complete in code. The location and speech prototype is split into testable units, duplicate view speech code is removed, and the Gloucestershire test route is an explicit fixture.

## Work Completed

### Address formatting separated

- Added `MotoGuide/Address.swift` with the `Address` model and `AddressFormatter` for spoken text.
- Removed address formatting from `LocationManager.swift`.

### Announcement logic separated

- Added `MotoGuide/AnnouncementDecision.swift` with pure functions for:
  - address change detection
  - repeat-preference handling
  - speech text generation
- `LocationManager` now delegates speech text decisions to `AnnouncementDecision` and only handles iOS services (GPS, geocoding, `AVSpeechSynthesizer`).

### Test route fixture

- Added `MotoGuide/TestRouteFixture.swift` with 11 named waypoints along the Gloucestershire test route (Nailsworth to Stonehouse).
- `LocationManager.logTestLocation()` cycles through `TestRouteFixture.waypoints`.

### View cleanup

- Removed unused `AVSpeechSynthesizer` and `speak(address:)` from `ContentView.swift`.
- Speech now flows only through `LocationManager`.

### Unit tests

- `MotoGuideTests/AddressTests.swift` — equality, formatting, JSON.
- `MotoGuideTests/AnnouncementDecisionTests.swift` — change detection, repeat rules, speech text.
- `MotoGuideTests/TestRouteFixtureTests.swift` — waypoint count, coordinate consistency, route bounds.
- Updated `MotoGuideTests/LocationManagerTests.swift` — interval throttling and test-mode behaviour.

## Done Criteria

| Criterion | Status |
|-----------|--------|
| Location-change logic testable without real GPS | Done — `AnnouncementDecisionTests` |
| Speech text generation testable without `AVSpeechSynthesizer` | Done — `AddressTests`, `AnnouncementDecisionTests` |
| App still speaks address changes in test mode | Done — `LocationManager` unchanged behaviour, uses extracted logic |

## Test Run

Command:

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'platform=iOS Simulator,name=iPhone 15' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData
```

Expected result: all unit tests pass in the iOS Simulator.

Actual result: **BUILD SUCCEEDED** and **TEST SUCCEEDED** on iPhone 17 simulator (iOS 26.3.1).

Command used:

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData -only-testing:MotoGuideTests
```

17 unit tests passed across `AddressTests`, `AnnouncementDecisionTests`, `TestRouteFixtureTests`, and `LocationManagerTests`.

## Next Step

Milestone 2: define ride-safe announcement rules (quiet mode, names-only mode, throttling, boundary-level repeat controls).

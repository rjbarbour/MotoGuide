# Location Screen Situational Awareness — Design

Date: 2026-07-02
Status: MVP1 completion scope (Milestone 6)

## Purpose

MotoGuide is an ambient place-awareness companion, not a navigation app. Navigation apps answer: *turn here, in 200 m, take the second exit*. MotoGuide answers: *where am I in the landscape, and what larger places am I near or inside?*

The Location screen gives riders a **glanceable geographic context screen** they can open at a stoplight, fuel stop, or scenic pull-off. It complements helmet audio announcements and does not compete with turn-by-turn navigation for attention while moving.

MVP1 decision: complete the Location screen using live coordinate, Apple reverse geocoding, MapKit, and lightweight nearby-place search. Do not add deterministic UK place/boundary data before the first field trial on 2026-07-03.

### vs navigation apps

| Navigation apps | MotoGuide Location screen |
|-----------------|-------------------|
| Route, ETA, next manoeuvre | Current place in hierarchy |
| Street-level turn detail | County / region / country context |
| Constant screen attention | Optional, short glances |
| Corners and junctions | Nearby towns and distances |
| Optimised for driving decisions | Optimised for orientation |

MotoGuide should remain mountable beside a nav app: nav on one screen corner, MotoGuide Location available when the rider deliberately opens the app.

## Recommendation: map-first single map + compact overlay

**Use one MapKit map as the primary surface**, with compact overlays for current place context. Do not use two maps at different zoom levels.

### Why not dual map

- Splits attention on a small phone screen; harder to parse at a glance.
- Doubles MapKit work, memory, and battery on a background location app.
- Two zoom levels still do not show administrative boundaries without a boundary dataset (Milestone 3).
- Pan/zoom on two maps increases unsafe interaction while riding.

### Single-map approach

- **Map region**: auto-follow user location with a **context-aware zoom** that defaults to roughly **4–8 km radius**, about twice the current visible area. This should show the current road network and neighbouring settlements without pretending to be turn-by-turn nav.
- **Optional zoom presets** (stopped only): *Local* (~2 km), *Area* (~10 km), *Region* (~50 km). Default follows speed: locked *Area* zoom while moving; presets enabled when speed is below a low threshold (e.g. &lt; 8 km/h) or device is stationary.
- **No free pan/zoom while moving** — map tracks user; reduces distraction and accidental interaction.

A compact **overlay or bottom sheet** supplies current place, hierarchy, last phrase, and nearby towns without pushing the map into a small preview. The map should feel closer to a full map app surface, but without route planning, turn banners, ETA, or search.

## UI layout (SwiftUI + MapKit)

Current app structure: **Location** is the primary screen. **Settings** opens from the toolbar gear. **Log** opens from the toolbar history/list button. There is no Start/Pause control.

Updated direction after phone review: the current stack is useful but too panel-heavy. Move towards a **full map with compact overlays**, similar in spirit to motorcycle map apps, while keeping MotoGuide's role distinct from navigation.

```
┌─────────────────────────────────────┐
│                                     │
│         [ MapKit map ]              │
│      user dot + heading             │
│      standard road map              │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ B4066 · Nailsworth            │  │ ← compact current-place overlay
│  │ Gloucestershire · England     │  │
│  │ Last: Welcome to Nailsworth…  │  │
│  └───────────────────────────────┘  │
│  Nearby: Stroud 6 km SW · ...       │
│                                     │
└─────────────────────────────────────┘
```

### Panel details

**Summary line**  
Plain-language sentence built from `Address`, e.g. *“B4066, Nailsworth, Gloucestershire”*. Omit invalid / `N/A` components. Mirrors spoken context without requiring audio.

**Hierarchy panel**  
Reuse the existing geographic model (`street` → `town` → `county` → `administrativeArea` / nation → `country`) and `BoundaryType` ordering. Prefer a compact presentation: current place as the primary line, larger contexts as chips or a single secondary line. Full hierarchy can expand from the overlay when stopped.

**Previous street**  
Show only when `BoundaryChangeDetector` would detect a street change (same logic as announcements). Single line, secondary style — enough context for “I just turned off X” without a trail history.

**Nearby towns**  
List **3–5 larger settlements** within ~30 km, sorted by distance, with compass bearing (e.g. *6 km SW*). MVP: `MKLocalSearch` with a region biased on current coordinate, filtered to localities (not POIs). Cache results; refresh on town/county change or every few km, not every GPS tick.

**Map**  
- `Map` (SwiftUI) or `MKMapView` wrapper with user location and heading when available.  
- Standard map type (roads visible; no satellite required for MVP).  
- User annotation centred; region updates from `LocationManager.lastKnownLocation`.  
- **No route line, no turn banners, no search bar** on the map itself.
- Default camera should show roughly twice the current map area. If the current implementation uses about 5 km latitudinal/longitudinal span, test about 10 km as the next default.

### Test mode

When `LocationManager.testMode` is on, the map and panels follow the Gloucestershire test route coordinates and geocoded addresses — same shared location source as Settings and Log.

## Data sources

| Need | MVP (M6) | Later |
|------|----------|-------|
| Current coordinate | `LocationManager.lastKnownLocation` | — |
| Hierarchy text | `Address` from existing reverse geocode | M3 deterministic place layer |
| Previous street | In-memory previous `Address` | — |
| Map tiles / roads | MapKit | — |
| Town / county **boundaries** on map | **Not in MVP** — no polygon overlay | M3 local boundary dataset |
| Nearest large towns | `MKLocalSearch` (or similar) within radius | M3 curated town list + offline |
| Facts on map | Compact last-spoken phrase or selected fact preview | Deeper place content |
| Offline map | Network via MapKit | Optional cached region (post-MVP) |

**Align with Milestone 3:** MVP map does **not** ship boundary polygons. The hierarchy panel carries boundary *names* from geocoding; the map shows **position and nearby places**, not legal/admin borders. When M3 adds offline boundary lookup, overlay county/town polygons as an enhancement (M6+ or folded into M3 completion).

Milestone 3 is deferred until after MVP1 field trial. For M6, no offline boundary lookup, local place dataset, or administrative polygon overlay is required.

### Geocoder behaviour

Share the same throttled geocode path as announcements (`locationCheckInterval`). The map UI reads `lastKnownAddress` — no extra geocode storms. Show a subtle “updating place…” state when coordinate is known but address is pending.

## MVP scope (Milestone 6)

**In scope**

- **Location** screen as the default app screen.
- Map-first layout with compact current-place overlay.
- Compact context: summary, hierarchy, previous street, nearby towns.
- Single MapKit map, user-following, context-aware default zoom showing roughly twice the current area.
- Stopped-only zoom presets (or speed-gated).
- Test mode parity with existing fixture.
- Unit tests for: hierarchy presentation from `Address`, nearby-town sorting/formatting, summary text builder, previous-street visibility rules.
- Preview / simulator support without live GPS.
- Visible states for waiting for GPS, location denied, geocoder failure, and Quiet mode.

**Out of scope for M6**

- Administrative boundary polygons (deferred to M3).
- Deterministic offline place/boundary data (deferred to post-field-trial M3).
- Turn-by-turn routing, route display, or “navigate to” handoff (MVP2).
- Custom map styling, satellite imagery, 3D buildings.
- Landmark layers, history pins, POI browsing.
- Voice interaction on the Location screen.
- Log entry creation from the Location screen, except explicit Test Mode stepping.
- Announcement settings duplication on Location (read-only reflection of Settings).

## Later enhancements

- **M3 integration:** county/town boundary overlays; offline hierarchy when geocoder is weak.
- **M5 integration:** optional compact fact/last phrase line in the overlay when Short Facts or Long Facts mode is on.
- **Tap nearest town:** copy name or hand off to navigation app (MVP2 POI handoff pattern).
- **Log correlation:** tap a log row to show that point on the map (Log enhancement).
- **Lock screen / widget:** minimal hierarchy line without opening the app (far future).
- **CarPlay:** not planned for MVP1.

## Interaction with Settings and Log

| Surface | Role relative to Location |
|---------|---------------------------|
| **Settings** | Source of truth for announcement style, intervals, test mode, boundary toggles. Location **displays** current `Address` and does not change speech policy. Quiet mode is visible on Location. |
| **Log** | Timestamped history of address changes. Location shows **now**; Log shows **then**. No merge in M6; future enhancement can jump from a log row to the map region. |
| **Location** | Read-mostly. No ride controls beyond Test Mode stepping and later stopped-only zoom presets. Riders configure behaviour in Settings, review history in Log, orient themselves on Location. |

Shared state: existing `LocationManager` (`@StateObject` in `ContentView`) — map view is another consumer of `lastKnownLocation`, `lastKnownAddress`, and test mode.

## Ride-safety constraints

1. **Glanceable first** — current place and mode are readable at a glance; the map is the primary visual surface.
2. **No interaction required while moving** — map auto-centres; no mandatory taps.
3. **Limit interaction while moving** — disable pan, pinch zoom, and zoom presets above ~8 km/h; re-enable when stopped.
4. **No flashing or rapid UI updates** — throttle nearby-town refresh; smooth map camera updates.
5. **Compact copy only** — summary fits one or two lines; nearby list capped at five rows or a single horizontally-scannable row.
6. **Audio remains primary** — map supports what was already spoken; it does not replace helmet announcements.
7. **Quiet mode visible** — rider should see that speech is off without opening Settings.
8. **Mounting** — design for portrait glance; landscape not required for M6.

Physical validation: confirm a 2-second glance at a stop provides useful context without reading fine map detail.

## Technical notes (iOS)

- **SwiftUI `Map`** (iOS 17+) with `MapCameraPosition.userLocation` is the preferred starting point; wrap in a small `MapContextView` for testability.
- Extract **pure functions** for summary text, hierarchy rows, and distance/bearing strings — test without MapKit.
- **Nearest towns:** `MKLocalSearch.Request` with `naturalLanguageQuery` e.g. “town” + `region` from coordinate; dedupe by name; filter by `MKMapItem` locality / pointOfInterestCategory where possible. Handle empty/network failure gracefully (hide section or show “Nearby places unavailable”).
- **Permissions:** Location screen assumes location already requested by `LocationManager`; show inline prompt if denied.
- **Battery:** map visible only when Location is open; do not run a second location pipeline.

## Open questions

1. **Nearest town definition:** Minimum population threshold, or purely distance-based from search results?
2. **Region label:** UK riders expect “England” / “Scotland” — confirm `administrativeArea` from Apple geocoder is consistently correct on the test route.
3. **Zoom constants:** Test doubled defaults first: Local ~2 km, Area ~10 km, Region ~50 km. Adjust after the phone ride.
4. **Heading arrow:** Show course on map when `CLLocation.course` is valid, or keep dot-only for simplicity?
5. **M5 facts on Location:** Show short/long fact under summary, or keep the screen focused on the last spoken phrase?
6. **Accessibility:** VoiceOver order — summary before map; verify hierarchy is navigable without seeing the map.

## References

- Product definition: `AGENTS.md`
- Milestones: `MILESTONES.md` (Milestone 6)
- Address model: `MotoGuide/Address.swift`
- Boundary ordering: `MotoGuide/BoundaryType.swift`, `MotoGuide/AnnouncementPolicy.swift`
- Current screen: `MotoGuide/ContentView.swift`

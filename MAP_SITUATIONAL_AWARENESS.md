# Location Screen Situational Awareness — Design

Date: 2026-07-01  
Status: Planning (Milestone 6)

## Purpose

MotoGuide is an ambient place-awareness companion, not a navigation app. Navigation apps answer: *turn here, in 200 m, take the second exit*. MotoGuide answers: *where am I in the landscape, and what larger places am I near or inside?*

The Location screen gives riders a **glanceable geographic context screen** they can open at a stoplight, fuel stop, or scenic pull-off. It complements helmet audio announcements and does not compete with turn-by-turn navigation for attention while moving.

### vs navigation apps

| Navigation apps | MotoGuide Location screen |
|-----------------|-------------------|
| Route, ETA, next manoeuvre | Current place in hierarchy |
| Street-level turn detail | County / region / country context |
| Constant screen attention | Optional, short glances |
| Corners and junctions | Nearby towns and distances |
| Optimised for driving decisions | Optimised for orientation |

MotoGuide should remain mountable beside a nav app: nav on one screen corner, MotoGuide Location available when the rider deliberately opens the app.

## Recommendation: single map + context stack (not dual map)

**Use one MapKit map with a fixed context panel above it**, not two maps at different zoom levels.

### Why not dual map

- Splits attention on a small phone screen; harder to parse at a glance.
- Doubles MapKit work, memory, and battery on a background location app.
- Two zoom levels still do not show administrative boundaries without a boundary dataset (Milestone 3).
- Pan/zoom on two maps increases unsafe interaction while riding.

### Single-map approach

- **Map region**: auto-follow user location with a **context-aware zoom** that defaults to roughly **2–4 km radius** (neighbourhood + surrounding towns visible). This shows the current street network and nearby settlements without pretending to be turn-by-turn nav.
- **Optional zoom presets** (stopped only): *Local* (~1 km), *Area* (~5 km), *Region* (~25 km). Default follows speed: locked *Area* zoom while moving; presets enabled when speed is below a low threshold (e.g. &lt; 8 km/h) or device is stationary.
- **No free pan/zoom while moving** — map tracks user; reduces distraction and accidental interaction.

A compact **“wider context” row** below the hierarchy (nearest towns with distances) supplies regional awareness without a second map.

## UI layout (SwiftUI + MapKit)

Current app structure: **Location** is the primary screen. **Settings** opens from the toolbar gear. **Log** opens from the toolbar history/list button. There is no Start/Pause control.

```
┌─────────────────────────────────────┐
│  Where you are                      │  ← one-line summary (large type)
│  B4066 · Nailsworth · Gloucestershire │
├─────────────────────────────────────┤
│  Hierarchy                          │
│  ● Street    B4066                  │  ← current level highlighted
│    Town      Nailsworth             │
│    County    Gloucestershire        │
│    Region    England                │
│    Country   United Kingdom           │
│  (previous street: Avening Road)    │  ← muted, only if known
├─────────────────────────────────────┤
│  Nearby                             │
│  Stroud        6 km SW              │
│  Cirencester  18 km E               │
│  Gloucester   22 km NW              │
├─────────────────────────────────────┤
│                                     │
│         [ MapKit map ]              │
│      user dot + heading             │
│      standard road map              │
│                                     │
└─────────────────────────────────────┘
```

### Panel details

**Summary line**  
Plain-language sentence built from `Address`, e.g. *“B4066, Nailsworth, Gloucestershire”*. Omit invalid / `N/A` components. Mirrors spoken context without requiring audio.

**Hierarchy panel**  
Reuse the existing geographic model (`street` → `town` → `county` → `administrativeArea` / nation → `country`) and `BoundaryType` ordering. Highlight the **most specific valid level** as “you are here”. Dim levels that are missing or `N/A`.

**Previous street**  
Show only when `BoundaryChangeDetector` would detect a street change (same logic as announcements). Single line, secondary style — enough context for “I just turned off X” without a trail history.

**Nearby towns**  
List **3–5 larger settlements** within ~30 km, sorted by distance, with compass bearing (e.g. *6 km SW*). MVP: `MKLocalSearch` with a region biased on current coordinate, filtered to localities (not POIs). Cache results; refresh on town/county change or every few km, not every GPS tick.

**Map**  
- `Map` (SwiftUI) or `MKMapView` wrapper with user location and heading when available.  
- Standard map type (roads visible; no satellite required for MVP).  
- User annotation centred; region updates from `LocationManager.lastKnownLocation`.  
- **No route line, no turn banners, no search bar** on the map itself.

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
| Short facts on map | Optional one-line from M5 if enabled | Deeper place content |
| Offline map | Network via MapKit | Optional cached region (post-MVP) |

**Align with Milestone 3:** MVP map does **not** ship boundary polygons. The hierarchy panel carries boundary *names* from geocoding; the map shows **position and nearby places**, not legal/admin borders. When M3 adds offline boundary lookup, overlay county/town polygons as an enhancement (M6+ or folded into M3 completion).

### Geocoder behaviour

Share the same throttled geocode path as announcements (`locationCheckInterval`). The map UI reads `lastKnownAddress` — no extra geocode storms. Show a subtle “updating place…” state when coordinate is known but address is pending.

## MVP scope (Milestone 6)

**In scope**

- New **Location** screen as the default app screen.
- Context stack: summary, hierarchy, previous street, nearby towns.
- Single MapKit map, user-following, context-aware default zoom.
- Stopped-only zoom presets (or speed-gated).
- Test mode parity with existing fixture.
- Unit tests for: hierarchy presentation from `Address`, nearby-town sorting/formatting, summary text builder, previous-street visibility rules.
- Preview / simulator support without live GPS.

**Out of scope for M6**

- Administrative boundary polygons (deferred to M3).
- Turn-by-turn routing, route display, or “navigate to” handoff (MVP2).
- Custom map styling, satellite imagery, 3D buildings.
- Landmark layers, history pins, POI browsing.
- Voice interaction on the map tab.
- Log entry creation from the Location screen, except explicit Test Mode stepping.
- Announcement settings duplication on Location (read-only reflection of Settings).

## Later enhancements

- **M3 integration:** county/town boundary overlays; offline hierarchy when geocoder is weak.
- **M5 integration:** optional fact chip under summary (*“Wool capital of the Cotswolds”*) when Short Facts or Long Facts mode is on.
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

1. **Glanceable first** — hierarchy and summary use large, high-contrast type; map is secondary context.
2. **No interaction required while moving** — map auto-centres; no mandatory taps.
3. **Limit interaction while moving** — disable pan, pinch zoom, and zoom presets above ~8 km/h; re-enable when stopped.
4. **No flashing or rapid UI updates** — throttle nearby-town refresh; smooth map camera updates.
5. **Short copy only** — summary fits one or two lines; nearby list capped at five rows.
6. **Audio remains primary** — map supports what was already spoken; it does not replace helmet announcements.
7. **Quiet mode visible** — rider should see that speech is off without opening Settings.
8. **Mounting** — design for portrait glance; landscape not required for M6.

Physical validation: confirm a 2-second glance at a stop provides useful context without reading fine map detail.

## Technical notes (iOS)

- **SwiftUI `Map`** (iOS 17+) with `MapCameraPosition.userLocation` is the preferred starting point; wrap in a small `MapContextView` for testability.
- Extract **pure functions** for summary text, hierarchy rows, and distance/bearing strings — test without MapKit.
- **Nearest towns:** `MKLocalSearch.Request` with `naturalLanguageQuery` e.g. “town” + `region` from coordinate; dedupe by name; filter by `MKMapItem` locality / pointOfInterestCategory where possible. Handle empty/network failure gracefully (hide section or show “Nearby places unavailable”).
- **Permissions:** map tab assumes location already requested by `LocationManager`; show inline prompt if denied.
- **Battery:** map visible only when tab is active; do not run a second location pipeline.

## Open questions

1. **Default screen:** Location replaces Settings as the launch screen.
2. **Nearest town definition:** Minimum population threshold, or purely distance-based from search results?
3. **Region label:** UK riders expect “England” / “Scotland” — confirm `administrativeArea` from Apple geocoder is consistently correct on the test route.
4. **Zoom constants:** Are 2 km / 5 km / 25 km the right presets for UK touring, or should they scale with speed?
5. **Heading arrow:** Show course on map when `CLLocation.course` is valid, or keep dot-only for simplicity?
6. **Boundary highlight without polygons:** Is hierarchy-only enough for MVP, or should we draw a simple circle/hex “you are in this county” approximation until M3?
7. **M5 facts on Location:** Show short/long fact under summary, or keep the screen focused on the last spoken phrase?
8. **Accessibility:** VoiceOver order — summary before map; verify hierarchy is navigable without seeing the map.

## References

- Product definition: `AGENTS.md`
- Milestones: `MILESTONES.md` (Milestone 6)
- Address model: `MotoGuide/Address.swift`
- Boundary ordering: `MotoGuide/BoundaryType.swift`, `MotoGuide/AnnouncementPolicy.swift`
- Current tabs: `MotoGuide/ContentView.swift`

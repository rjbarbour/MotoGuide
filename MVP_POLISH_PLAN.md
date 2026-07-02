# MotoGuide MVP Polish Plan

Date: 2026-07-02  
Status: Planning only — prepare implementation before the 2026-07-03 field trial  
Audience: First-time rider using MotoGuide as a situational-awareness companion alongside normal navigation

## Context

MotoGuide is now a working technical proof of concept with early product shape. Core location, reverse-geocoding, announcement policy, content modes, proxy-backed facts, onboarding, a primary Location screen, and helmet-audio support are implemented. The remaining MVP1 polish is about field readiness: clear first-run flow, complete Location screen, rider-facing settings, visible failure states, and review-safe privacy/location behavior.

MVP1 goal (from `AGENTS.md` and `MILESTONES.md`): a UK motorbike audio companion that speaks short place context on meaningful boundary changes, with Short Facts as the default mode — **not** turn-by-turn navigation.

This plan defines polish appropriate for a **first-time user** preparing for field trial (Milestone 8). It includes App Review and compliance preparation, but not full App Store launch polish.

---

## 1. First-Time User Journey

### 1.1 Ideal journey (target state)

| Step | What happens | Rider sees / hears |
|------|----------------|-------------------|
| **Launch** | App opens to a **home screen** (Map tab when M6 lands; interim: a simple **Ride** or **Now** screen) | One-line product purpose: *"Place awareness for your ride — works alongside your nav app."* |
| **Permissions** | In-app explanation **before** iOS location prompt; request When In Use first, upgrade to Always after rider taps "Start ride" | Plain copy: why background location is needed (announcements while screen is off / nav app in foreground) |
| **What to expect** | Short onboarding (2–3 cards or one scrollable screen), skippable | *"You'll hear town and county names as you ride. Keep your nav app running. Connect your helmet headset."* Example announcement. Quiet mode explained. |
| **First configuration** | Sensible defaults pre-selected; optional "Customise" link | Announcement style picker (Natural / Names only / Short facts / Quiet). Short Facts pre-selected. Advanced settings collapsed. |
| **Start ride** | Rider mounts phone, opens nav app, starts MotoGuide (or it auto-starts tracking after onboarding) | Status: **Listening**, current place hierarchy, last spoken phrase, mode badge |
| **During ride** | Audio on boundary changes; screen optional | Glanceable status if tab opened at a stop; no interaction required while moving |
| **After ride** | Optional: review last announcements in Log | Log shows rider-friendly place names, not raw coordinates first |

### 1.2 What confuses a PoC user today

| Pain point | Current behaviour | Why it hurts |
|------------|-------------------|--------------|
| **No onboarding** | App opens straight to Settings | Rider does not know MotoGuide is not a nav app, or what it will say |
| **Permissions without context** | `requestAlwaysAuthorization()` on `LocationManager` init; generic plist strings | iOS dialog appears before value is explained; "provide better services" is vague |
| **Settings as home tab** | `TabView` leads with Settings | Feels like a config panel, not a product |
| **Debug controls visible** | Test Mode, Speak After Every Geocode (Debug), 1-second interval | Looks broken or overwhelming; easy to enable pathological speech |
| **Developer Log tab** | Coordinates, JSON-ish address fields, manual Log button | Useful for dev; alien to a rider |
| **Internal language** | "Check Interval", "Geocode", "Nation", "Announce" section | Jargon; "Nation" ≠ "England" in rider mental model |
| **No live status** | `lastKnownAddress` exists but is not shown on Settings | Rider cannot confirm "it knows where I am" before riding |
| **No permission-denied UX** | Errors only `print()` to console | Silent failure if location denied |
| **No empty states** | Log empty list; no "waiting for GPS" | Rider thinks app is broken |
| **Announcement style unclear** | "Natural" undefined | Rider does not know difference from Names only / Short facts |
| **Bluetooth delay slider** | 0–3 s slider with no explanation | Tuning knob without label; most riders should never see it |

### 1.3 Assumptions

- First-time user is a UK touring motorcyclist, familiar with Google Maps / Apple Maps / Waze, sceptical of another nav app.
- Primary validation device: iPhone 17 Pro Max, iOS 26.5.1, Nex Xcom helmet headset.
- First MVP1 field trial target is 2026-07-03.
- Deterministic UK place/boundary data is deferred until after MVP1 field trial.

---

## 2. Recommended Polish (Prioritised)

Grouped for MVP1 field readiness. **Must** = before first external rider or M8; **Should** = before M8 if time allows; **Could** = nice for M8, deferrable to post-trial.

### 2.1 Onboarding and permissions copy — **Must**

- 2–3 screen onboarding: purpose, how it differs from nav, helmet + background location note.
- Replace plist usage strings with rider-facing copy, e.g. *"MotoGuide uses your location to announce towns and counties while you ride, even when the screen is off or another app is open."*
- Defer `requestAlwaysAuthorization()` until after onboarding + explicit "Start" (aligns with M1 open question).
- Add `NSLocationAlwaysAndWhenInUseUsageDescription` if missing (simulator logs show gap).
- Post-denial screen: Open Settings deep link, explain limited functionality.

### 2.2 Default settings for real rides — **Must**

- Hide or collapse debug: Test Mode, Speak After Every Geocode, 1 s / 2 s intervals → **Advanced** or `#if DEBUG` only.
- Default interval **10 s** for real rides.
- Street announcements **off** (already default in `BoundaryAnnouncementSettings.ridingDefaults`).
- Pre-select **Short Facts** announcement style.
- Bluetooth delay: keep 0.5 s internally; hide from Simple settings.

### 2.3 Rider-facing language — **Must**

| Current | Proposed |
|---------|----------|
| Check Interval | Location update frequency / "How often to check location" (Advanced) |
| Speak After Every Geocode (Debug) | (hidden) |
| Announce → Street / Town / County / Nation / Country | What to announce → Road / Town / County / Region / Country |
| Nation | Region (England, Scotland, Wales, NI) |
| Natural | Places + greetings (or "Normal") |
| Short Facts | Places + one fact |
| Test Mode | (Advanced) Simulate Gloucestershire route |

Rename UI only where rider-visible; keep code identifiers stable.

### 2.4 Status at a glance — **Must** (interim), **Should** (full with M6)

**Before Map tab (interim Must):**

- Add compact **status header** on home/settings: current town/county, announcement mode, listening indicator.
- Show **last spoken** phrase and timestamp.
- "Updating location…" / "Waiting for GPS" empty state.

**With Map tab (Should, M6):**

- Map as default tab with hierarchy stack per `MAP_SITUATIONAL_AWARENESS.md`.
- Quiet mode banner on Map: *"Announcements muted"*.

### 2.5 Empty states and tab structure — **Should**

| Tab (target) | Role |
|--------------|------|
| **Map** (default, M6) | Where am I; hierarchy; nearby towns |
| **Ride** or **Now** (interim if Map not ready) | Status + last spoken + start/pause |
| **Settings** | Simple + Advanced sections |
| **Log** | Ride history; rename to **History**; place names first, coordinates in disclosure |

- Log empty state: *"Announcements will appear here as you ride."*
- Consider demoting Log to secondary placement (last tab).

### 2.6 Visual design basics — **Should**

Not App Store polish. Minimum:

- Consistent navigation title and section headers.
- SF Symbols for mode (speaker / speaker.slash) and location (location.fill).
- Readable type scale: status line ≥ title3.
- System background; avoid default plain `Form` grey slab feel with one accent colour.
- App icon and launch screen: existing assets OK for MVP1; no marketing screenshots.

### 2.7 Error and permission-denied handling — **Must**

- Surface location errors in UI (not only `print`).
- States: denied, restricted, reduced accuracy, no GPS fix, geocoder failure.
- Copy: actionable, calm, short.
- Audio session failure: non-blocking banner.

### 2.8 What NOT to do yet — explicit deferrals

| Defer | Reason |
|-------|--------|
| App Store submission polish | MILESTONES.md out of scope for MVP1 |
| Accounts, sign-in, cloud sync | No MVP1 value |
| Route planning, turn-by-turn, POI handoff | MVP2 |
| Full custom instruction UI | M7 |
| Deterministic UK place data and offline boundary lookup | Post-field-trial M3 |
| Administrative boundary polygons on map | Post-field-trial M3 |
| CarPlay, widgets, lock screen | Later |
| Localisation beyond en-GB | UK-only MVP1 |
| Curated marketing onboarding video | Could post-trial |
| In-app analytics / crash reporting SDK | Could add minimal logging for M8 notes only |
| Hiding Log entirely | Keep for field-trial debugging; polish presentation only |

---

## 3. Settings Simplification Proposal

### 3.1 Simple (default, expanded)

**Announcement style** (picker)

- Places + greetings → `natural`
- Names only → `namesOnly`
- Places + one fact → `shortFacts`
- Quiet → `quiet`

**What to announce** (multi-select or sensible preset)

- Preset **Towns & counties** (town + county + region + country on; road off) — matches riding defaults.
- Optional toggles: Road, Town, County, Region, Country.

**Ride tools**

- Link: *Simulate test route* → reveals Test Mode (Advanced) with Gloucestershire explanation.

### 3.2 Advanced (collapsed `DisclosureGroup`)

- Location check interval (10 / 30 / 60 s for riders; full list for dev builds).
- Speak after every location lookup (debug).
- Bluetooth audio delay.
- Test mode toggle.
- Reset to defaults.

### 3.3 Sensible defaults table

| Setting | PoC default (code) | MVP1 ride default | Notes |
|---------|-------------------|-------------------|-------|
| `contentMode` | `.shortFacts` | `.shortFacts` | Confirmed default for MVP1 |
| `locationCheckInterval` | 10 s | **10 s** | Confirmed default for MVP1 |
| `announceStreet` | false | false | Roads too chatty on motorways |
| `announceTown` | true | true | Core value |
| `announceCounty` | true | true | Core value |
| `announceNation` | true | true | Label as Region in UI |
| `announceCountry` | true | true | UK rides: rare but meaningful at borders |
| `speakAfterEveryGeocode` | false | false | Hidden |
| `testMode` | false | false | Hidden |
| `bluetoothDelaySeconds` | 0.5 | 0.5 | Hidden |
| Default tab | Settings | **Map** (post-M6) or **Ride/Now** interim | |
| Permission timing | on init | after onboarding | |

`BoundaryAnnouncementSettings.ridingDefaults` in code already matches most ride defaults. Keep the `10 s` interval and Short Facts default; focus polish on permission timing and UI exposure, not these defaults.

---

## 4. App Quality Spec

Use this as the implementation bar for the first-time rider polish.

### 4.1 Product principles

- One primary job per screen. Location answers "where am I?", Settings answers "what should MotoGuide say?", History answers "what did it say?".
- Audio remains the primary ride interface. The screen is for setup, stops, and quick confidence checks.
- Progressive disclosure. First-run and simple Settings show only the decisions a rider needs. Advanced holds debug and tuning.
- Every waiting state is visible. Permission, GPS, geocoder, proxy facts, and audio setup must not fail silently.
- Every recovery path is human-operable. Use short copy and direct actions such as Open Settings, Try Again, or Switch to Names Only.
- Keep interaction safe while moving. No required taps, no route-like decisions, no dense reading, no animated distraction.
- Use native iOS patterns. SwiftUI navigation, sheets, toggles, pickers, SF Symbols, Dynamic Type, VoiceOver labels, and standard system colors.
- Prefer real app state over tutorial text. Show current place, last spoken phrase, mode, and tracking state.
- Treat network and AI as optional. If facts fail, the app speaks names.

### 4.2 Anti-patterns to avoid

- Settings-first launch.
- Permission prompt before explaining value.
- Debug controls in the primary rider path.
- Jargon such as geocode, Nation, or check interval on first-run screens.
- Blank screens while waiting for GPS or denied permissions.
- Route, ETA, turn banner, search, or POI UI that makes MotoGuide look like navigation.
- Speech that sounds like an instruction to ride, turn, speed up, stop, or make a safety decision.
- Blocking core announcements on the fact proxy.
- Claims that generated facts are exhaustive, authoritative, live safety data, or emergency information.
- Hidden backend requirements during review or TestFlight.

### 4.3 Apple review and compliance preparation

Sources checked on 2026-07-02:

- Apple App Review Guidelines: `https://developer.apple.com/app-store/review/guidelines/`
- Apple App Privacy Details: `https://developer.apple.com/app-store/app-privacy-details/`
- Apple Human Interface Guidelines pages for privacy, onboarding, and accessibility require JavaScript in this environment, but remain implementation references.

Review risks to address before TestFlight or App Store review:

- **Location Services:** Location is core to MotoGuide, but permission copy must clearly explain background town/county announcements. Do not imply emergency, autonomous vehicle control, or navigation safety features.
- **Background modes:** Audit Info.plist background modes. Keep only modes that are genuinely used and explain background location/audio in App Review notes.
- **Privacy policy:** Draft a clear policy covering device location use, Apple reverse geocoding, fact proxy requests, retained data, logs, and deletion/consent requests.
- **App Privacy labels:** Inventory all data collection before submission. Fact proxy requests should avoid exact coordinates where possible; document whether place names, country context, request IDs, or diagnostics are collected.
- **Generated facts:** Keep prompts and sanitization bounded. Facts must be short, non-instructional, and safe to ignore while riding.
- **Backend availability:** The fact proxy must be live during review. If review needs a token, provide it in App Review notes or provide a demo mode.
- **Metadata accuracy:** Describe MotoGuide as an audio place-awareness companion, not a navigation app, not a safety app, and not an emergency service.
- **Physical safety:** The app must not encourage interaction while riding. Setup happens before the ride or at a stop.
- **Support and contact:** Add support/privacy links before public App Store submission. For the 2026-07-03 field trial, record the missing items as review blockers, not field blockers.

### 4.4 Field-trial app quality bar

- The app opens to Location.
- Onboarding explains purpose, location, background use, helmet audio, and normal navigation coexistence.
- The rider can start without touching Advanced.
- Quiet mode is visible when enabled.
- Current place, last spoken phrase, and mode are visible in one glance.
- Location denied, no GPS, geocoder failed, proxy unavailable, and audio setup failed have visible states or fallbacks.
- History shows place names first; coordinates are secondary.
- Test Mode remains available for development but is not confused with normal riding.
- Build is installed on Robert's iPhone before the 2026-07-03 field trial.

## 5. Suggested Milestone: M6.5 First-Time Rider Polish

### 5.1 Placement in `MILESTONES.md`

Insert **Milestone 6.5: First-Time Rider Polish And Review Readiness** after **Milestone 6: Location Screen Completion** and before **Milestone 8: MVP1 Field Trial**.

Rationale:

- M2 delivers announcement modes and policy; polish renames and defaults should align with M2 completion, but full journey needs a complete **Location** home screen.
- M4 real-ride audio validation can use a **lightweight** subset of Must items (permissions copy, hide debug, status header).
- M8 field trial should not run on raw PoC chrome.
- M7 custom instructions remain post-polish; avoid scope creep.
- M3 deterministic place data is deferred until after field trial.

**Parallel track:** Must items marked in §2 can start during M4 as "M6.5a" if field testing begins before Map lands.

### 5.2 Work items

| # | Item | Depends on |
|---|------|------------|
| 1 | Onboarding flow + deferred permission request | — |
| 2 | Rider-facing plist permission strings | — |
| 3 | Settings → Simple / Advanced split; hide debug | M2 modes stable |
| 4 | Rider language pass (UI strings) | M2 |
| 5 | Complete Location home screen status and map context | M6 |
| 6 | Error and permission-denied states | — |
| 7 | Log → History presentation; empty states | — |
| 8 | Map tab as default home | M6 |
| 9 | Quiet indicator on Map | M6 |
| 10 | Visual pass (typography, symbols, spacing) | 1–7 |
| 11 | Update ride test checklist for first-time flow | M4 checklist |
| 12 | App Review and privacy readiness notes | 1–7 |
| 13 | Info.plist background-mode audit | 1–7 |

### 5.3 Done criteria

- [ ] New rider can complete onboarding and start tracking without enabling debug settings.
- [ ] Location permission rationale is visible before the system prompt.
- [ ] Denied permission shows recovery UI, not a blank screen.
- [ ] Home tab shows current place and last announcement within one glance.
- [ ] Settings Simple section has ≤ 3 decision areas; Advanced holds debug and tuning.
- [ ] No rider-visible use of "geocode" or "Nation" without explanation.
- [ ] Default interval is 10 s; street off; Short Facts mode selected.
- [ ] Map tab is default (when M6 complete) with quiet banner when applicable.
- [ ] Simulator and device smoke test documented for first-time path.
- [ ] App Review and privacy risks are documented before broader external testing.
- [ ] Ready for the 2026-07-03 field trial without developer briefing.

---

## 6. Executive Summary

- MotoGuide works technically and has early product shape; the remaining MVP1 gap is field readiness.
- First-time riders need a clear story: **companion audio for place awareness**, not navigation, before the location permission dialog.
- **Must-have polish:** onboarding, permission copy, hide debug controls, rider language, live status, error states, confirmed defaults (10 s interval, Short Facts, no street).
- **Should-have:** complete Location home, History tab polish, basic visual consistency, Simple vs Advanced settings.
- **Defer:** deterministic place data, App Store launch polish, accounts, routing, CarPlay, boundary polygons, custom instructions UI.
- Settings simplify to **Announcement style** + **What to announce**; everything else in Advanced.
- Code defaults for interval, content mode, and boundaries are already ride-sensible; main gaps are **permission timing** and **UI exposure**.
- Milestone 6.5 sits between Location completion (M6) and Field Trial (M8).
- Location screen (`MAP_SITUATIONAL_AWARENESS.md`) is the strongest single UX upgrade for "where am I" without competing with nav apps.
- Field trial on 2026-07-03 should test **ride value**, not confusion about toggles and jargon.

# MotoGuide MVP Polish Plan

Date: 2026-07-01  
Status: Planning only — no implementation in this document  
Audience: First-time rider using MotoGuide as a situational-awareness companion alongside normal navigation

## Context

MotoGuide today is a working technical proof of concept. Core location, reverse-geocoding, announcement policy, content modes, and helmet audio are implemented. The UI still reads like a developer test harness: Settings and Log tabs only, debug toggles in plain sight, internal terminology (`geocode`, `Nation`, `Check Interval`), and no explanation of what the app does or what to expect on a ride.

MVP1 goal (from `AGENTS.md` and `MILESTONES.md`): a UK motorbike audio companion that speaks short place context on meaningful boundary changes, with names-only, short-facts, and quiet modes — **not** turn-by-turn navigation.

This plan defines polish appropriate for a **first-time user** preparing for field trial (Milestone 8), without App Store launch scope.

---

## 1. First-Time User Journey

### 1.1 Ideal journey (target state)

| Step | What happens | Rider sees / hears |
|------|----------------|-------------------|
| **Launch** | App opens to a **home screen** (Map tab when M6 lands; interim: a simple **Ride** or **Now** screen) | One-line product purpose: *"Place awareness for your ride — works alongside your nav app."* |
| **Permissions** | In-app explanation **before** iOS location prompt; request When In Use first, upgrade to Always after rider taps "Start ride" | Plain copy: why background location is needed (announcements while screen is off / nav app in foreground) |
| **What to expect** | Short onboarding (2–3 cards or one scrollable screen), skippable | *"You'll hear town and county names as you ride. Keep your nav app running. Connect your helmet headset."* Example announcement. Quiet mode explained. |
| **First configuration** | Sensible defaults pre-selected; optional "Customise" link | Announcement style picker (Natural / Names only / Short facts / Quiet). Advanced settings collapsed. |
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
- Polish ships incrementally; some **Must** items can land before Map tab (M6).

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
- Default interval **30 s** for real rides (current code default is 10 s; M2 calls for conservative defaults).
- Street announcements **off** (already default in `BoundaryAnnouncementSettings.ridingDefaults`).
- Pre-select **Natural** announcement style (current default).
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
| Administrative boundary polygons on map | M3 |
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

- Location check interval (30 / 60 / 120 s for riders; full list for dev builds).
- Speak after every location lookup (debug).
- Bluetooth audio delay.
- Test mode toggle.
- Reset to defaults.

### 3.3 Sensible defaults table

| Setting | PoC default (code) | MVP1 ride default | Notes |
|---------|-------------------|-------------------|-------|
| `contentMode` | `.natural` | `.natural` | Good |
| `locationCheckInterval` | 10 s | **30 s** | M2: conservative; reduce geocode churn |
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

`BoundaryAnnouncementSettings.ridingDefaults` in code already matches most ride defaults; change interval and UI exposure, not boundary booleans.

---

## 4. Suggested Milestone: M6.5 First-Time User Polish

### 4.1 Placement in `MILESTONES.md`

Insert **Milestone 6.5: First-Time User Polish** after **Milestone 6: Situational Awareness Map** and before **Milestone 8: MVP1 Field Trial**.

Rationale:

- M2 delivers announcement modes and policy; polish renames and defaults should align with M2 completion, but full journey needs a **home screen** (M6 Map).
- M4 real-ride audio validation can use a **lightweight** subset of Must items (permissions copy, hide debug, status header).
- M8 field trial should not run on raw PoC chrome.
- M7 custom instructions remain post-polish; avoid scope creep.

**Parallel track:** Must items marked in §2 can start during M4 as "M6.5a" if field testing begins before Map lands.

### 4.2 Work items

| # | Item | Depends on |
|---|------|------------|
| 1 | Onboarding flow + deferred permission request | — |
| 2 | Rider-facing plist permission strings | — |
| 3 | Settings → Simple / Advanced split; hide debug | M2 modes stable |
| 4 | Rider language pass (UI strings) | M2 |
| 5 | Status header / Ride screen (pre-Map interim) | — |
| 6 | Error and permission-denied states | — |
| 7 | Log → History presentation; empty states | — |
| 8 | Map tab as default home | M6 |
| 9 | Quiet indicator on Map | M6 |
| 10 | Visual pass (typography, symbols, spacing) | 1–7 |
| 11 | Update ride test checklist for first-time flow | M4 checklist |

### 4.3 Done criteria

- [ ] New rider can complete onboarding and start tracking without enabling debug settings.
- [ ] Location permission rationale is visible before the system prompt.
- [ ] Denied permission shows recovery UI, not a blank screen.
- [ ] Home tab shows current place and last announcement within one glance.
- [ ] Settings Simple section has ≤ 3 decision areas; Advanced holds debug and tuning.
- [ ] No rider-visible use of "geocode" or "Nation" without explanation.
- [ ] Default interval is 30 s; street off; Natural mode selected.
- [ ] Map tab is default (when M6 complete) with quiet banner when applicable.
- [ ] Simulator and device smoke test documented for first-time path.
- [ ] Ready for M8 field trial without developer briefing.

---

## 5. Executive Summary

- MotoGuide works technically but presents as a **developer test harness** (Settings-first, debug toggles, Log with coordinates).
- First-time riders need a clear story: **companion audio for place awareness**, not navigation — before the location permission dialog.
- **Must-have polish:** onboarding, permission copy, hide debug controls, rider language, live status, error states, conservative defaults (30 s interval, no street).
- **Should-have:** Map as home (M6), History tab polish, basic visual consistency, Simple vs Advanced settings.
- **Defer:** App Store polish, accounts, routing, CarPlay, boundary polygons, custom instructions UI.
- Settings simplify to **Announcement style** + **What to announce**; everything else in Advanced.
- Code defaults for boundaries are already ride-sensible; main gaps are **interval (10 → 30 s)**, **permission timing**, and **UI exposure**.
- Place new work as **Milestone 6.5** between Map (M6) and Field Trial (M8); start Must items during M4 if testing early.
- Map tab (`MAP_SITUATIONAL_AWARENESS.md`) is the strongest single UX upgrade for "where am I" without competing with nav apps.
- Field trial (M8) should run on polished UX so feedback is about **ride value**, not confusion about toggles and jargon.

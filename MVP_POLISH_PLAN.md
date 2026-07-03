# MotoGuide MVP Polish Plan

Date: 2026-07-03  
Status: Implementation in progress — keep synchronized before the 2026-07-03 field trial  
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
| **Launch** | App opens to the **Location** screen after onboarding | Current place, hierarchy, last spoken phrase, mode, and location status |
| **Permissions** | In-app explanation **before** iOS location prompt; request location after onboarding | Plain copy: why background location is needed (announcements while screen is off / nav app in foreground) |
| **What to expect** | Short onboarding (2–3 cards or one scrollable screen), skippable | *"You'll hear town and county names as you ride. Keep your nav app running. Connect your helmet headset."* Example announcement. Quiet mode explained. |
| **First configuration** | Sensible defaults pre-selected; optional "Customise" link | Announcement style picker (Natural / Names only / Short facts / Quiet). Short Facts pre-selected. Advanced settings collapsed. |
| **Ride begins** | Rider mounts phone, opens nav app, and leaves MotoGuide running after onboarding | Status: **Always running**, current place hierarchy, last spoken phrase, mode badge |
| **During ride** | Audio on boundary changes; screen optional | Glanceable status if Location is open at a stop; no interaction required while moving |
| **After ride** | Optional: review last announcements in Log | Log shows rider-friendly place names, not raw coordinates first |

### 1.2 Remaining first-time rider risks

| Risk | Current behaviour | Why it matters |
|------|-------------------|----------------|
| **Physical behavior unverified** | OTA deployment to Robert's iPhone is recorded, but launch/ride behavior still needs field validation | Field testing must confirm permissions, background tracking, headset audio, and proxy facts on the phone |
| **Debug controls visible** | Test Mode, Speak After Every Geocode, Bluetooth delay, and proxy diagnostics are nested under Advanced / Developer | Useful for development, but still too easy for a rider to create noisy behavior |
| **Developer Log language** | Log still uses developer naming and exposes coordinates directly | Useful for field debugging, but not yet rider-friendly History |
| **Internal language remains** | "Location check frequency", "Speak After Every Geocode", and "Natural" still need a rider-language pass | Jargon makes the app feel unfinished |
| **Proxy/audio recovery incomplete** | Location and geocoder failures are visible, but proxy and audio failures mostly rely on diagnostics or console output | A rider needs visible fallback status if facts or speech fail |
| **Fact sequence repetition** | Refined prompts produce better isolated facts, but nearby towns can repeat Cotswolds, limestone, stone buildings, wool, cloth, mills, and old-route language | Adult touring riders need specific, locally meaningful context that stays fresh across a ride sequence |
| **TTS voice quality poor** | Apple voices remain available, but ride-facing quality is not good enough | Try ElevenLabs through the proxy, keep Apple speech as fallback, and validate through the Nex Xcom headset |
| **Busy riding conditions** | Announcements are sparse and can be muted, but they are not yet delayed by cornering, braking, acceleration, or unstable heading | Add ride-aware announcements after MVP1 if field testing shows timing distraction |
| **Location screen incomplete** | Full-map layout, compact overlays, summary, context line, last spoken phrase, quiet status, speed-gated map interaction, manual zoom/reset controls, and key empty states exist | Nearby towns, previous street, stopped-only zoom presets, presentation tests, and field readability pass remain |
| **Status line and map controls** | Location screen shows redundant status text and zoom button behavior remains unclear in real use | Remove duplicate `Location is active.` status in normal mode; make zoom controls direction and hit area obvious and reliable |
| **Build metadata visibility** | Build version and timestamp not consistently shown in the main screen title area | Show compact build metadata on main screen in test mode |
| **Settings readability and hit targets** | Settings still uses compact rows, placeholder-only context fields, low-contrast secondary text, and toggle controls where the effective target can feel like the switch | Settings must be readable outdoors on a motorbike: high contrast, larger type, clear labels, full-width tappable rows, and enough vertical spacing for gloved use |
| **Announcement style unclear** | "Natural" is still undefined in the UI | Rider may not understand the difference from Names Only / Short Facts |
| **Bluetooth delay exposed** | 0-3 s slider is visible in Advanced | Most riders should not need to tune this before a field ride |

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
- Request location only after onboarding has explained why it is needed.
- Keep `NSLocationAlwaysUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, and `NSLocationWhenInUseUsageDescription` rider-facing.
- Post-denial screen: Open Settings deep link, explain limited functionality.

### 2.2 Default settings for real rides — **Must**

- Hide or collapse debug: Test Mode, Speak After Every Geocode, Bluetooth delay, and proxy diagnostics → **Advanced**, **Developer**, or `#if DEBUG` only.
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

**Location screen (M6):**

- Keep compact status header: current place, announcement mode, and always-running indicator.
- Show **last spoken** phrase and timestamp.
- Show "Waiting for GPS", permission-denied, and geocoder-failure states.
- Keep the map-first layout per `MAP_SITUATIONAL_AWARENESS.md`: full map, compact overlay, current place, mode, and last phrase.
- Add nearby towns, previous street, stopped-only zoom presets, and presentation tests.
- Show low-level location status text only in test mode to reduce non-signal clutter at ride speed.
- Keep Quiet mode visible on Location.
- Keep map controls reliable: zoom in/out and reset should have a larger, explicit hit area and predictable behavior.

### 2.5 Empty states and entry points — **Should**

| Entry (target) | Role |
|--------------|------|
| **Location** (primary screen) | Where am I; hierarchy; nearby towns |
| **Settings** (toolbar sheet) | Simple + Advanced sections |
| **Log / History** (toolbar sheet) | Ride history; place names first, coordinates in disclosure |

- Log empty state: *"Announcements will appear here as you ride."*
- Keep Log in the toolbar for field debugging; rename to History later if broader testing starts.

### 2.6 Visual design basics — **Should**

Not App Store polish. Minimum:

- Consistent navigation title and section headers.
- SF Symbols for mode (speaker / speaker.slash) and location (location.fill).
- Readable type scale: status line ≥ title3.
- System background; avoid default plain `Form` grey slab feel with one accent colour.
- App icon and launch screen: existing assets OK for MVP1; no marketing screenshots.
- Settings must assume glare, vibration, and brief glances from a stopped or slow-moving motorbike.
- Settings row labels should use strong contrast and at least title3-scale text for interactive rows.
- Toggle-style rows should make the whole row tappable, not just the switch.
- Rider context fields need visible question labels; example text must not be the only label.

### 2.7 Voice quality — **Should before repeated field testing**

- Keep installed Apple voices available as fallback.
- Add proxy-backed ElevenLabs speech as the first non-Apple provider.
- Keep ElevenLabs API key, voice id, model id, and output format server-side.
- Add a small speech provider setting and keep the preview path.
- Keep the selected provider, voice fallback, rate, pitch, and volume stable across launches.
- Test through the Nex Xcom headset; phone-speaker quality is not enough.

### 2.8 Error and permission-denied handling — **Must**

- Surface location errors in UI (not only `print`).
- States: denied, restricted, reduced accuracy, no GPS fix, geocoder failure.
- Copy: actionable, calm, short.
- Audio session failure: non-blocking banner.

### 2.9 Fact quality — **Should before broader testing**

- Treat Short Facts as a useful short blurb, not a tiny trivia sentence. Current refined target: 35-45 words.
- Make Long Facts richer but still bounded and interruptible. Current refined target: 75-90 words.
- Assume adult, middle-aged touring riders. Avoid patronising explanations and school-level definitions.
- Add optional coarse home/familiar-region context so familiar places are not explained as if the rider knows nothing about them.
- Add ride-sequence context before broader testing: previous spoken places, previous topics, avoid topics, desired novelty, and familiarity policy.
- Add a small topic memory for the last 3-5 spoken facts.
- Prefer names-only or silence over filler when the next town has no distinct fact after recent nearby announcements.
- Add a home quiet radius setting after MVP1 field validation: Off, 5 miles, 10 miles, 25 miles.
- Examples of bad output: "Wales is a country in the UK"; "Gloucestershire is a county in England"; generic population or administrative facts without why it matters.
- Examples of better output: a local industry, border story, road/landscape context, architectural marker, historic event, or why the place is notable on a ride.

### 2.9.1 Ride-aware announcements — **Post-field-trial unless timing distracts**

- Use **announcements** as the standard word for rider-facing speech.
- Use **Ride-aware announcements** for the feature that delays speech while the ride looks busy.
- Delay announcements while cornering, braking, accelerating, rapidly changing heading, or when motion/course data is uncertain.
- Release only the latest relevant held announcement when stopped or riding steadily.
- Do not play a backlog after a bend, roundabout, village hazard, or junction sequence.
- Add a max hold time, then shorten to names-only or drop stale content.
- Keep Quiet mode as the hard override.

### 2.10 What NOT to do yet — explicit deferrals

| Defer | Reason |
|-------|--------|
| Full App Store launch/submission polish | MVP1 only needs review-risk notes before field trial |
| Accounts, sign-in, cloud sync | No MVP1 value |
| Route planning, turn-by-turn, POI handoff | MVP2 |
| Open-ended rider questions | M10 |
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
| Ride-aware announcements | none | Post-field-trial option | Delay speech while busy; speak latest update when stopped or steady |
| Default screen | Location | **Location** | Keep Location as home |
| Permission timing | on init | after onboarding | |
| Voice | default `en-GB` | Best installed premium/enhanced `en-GB` | Add preview setting |
| Short Facts length | 35-45 words | Useful short blurb | Refined prompt target |
| Long Facts length | 75-90 words | Richer bounded blurb | Refined prompt target |
| Home context | none | Coarse home/familiar region only | No exact home address |
| Home quiet radius | none | Post-field-trial | Off / 5 / 10 / 25 miles; no exact home address sent to proxy |

`BoundaryAnnouncementSettings.ridingDefaults` in code already matches most ride defaults. Keep the `10 s` interval and Short Facts default; focus polish on permission timing and UI exposure, not these defaults.

---

## 4. App Quality Spec

Use this as the implementation bar for the first-time rider polish.

### 4.1 Product principles

- One primary job per screen. Location answers "where am I?", Settings answers "what should MotoGuide say?", History answers "what did it say?".
- Audio remains the primary ride interface. The screen is for setup, stops, and quick confidence checks.
- Announcements should happen at suitable moments. Delay or drop speech rather than talking over demanding riding conditions.
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
- Speech that continues through demanding cornering, braking, acceleration, or complex junction work when it could have been delayed.
- Backlog playback after a held period.
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
- Controlled rider preference hints are in scope now because they improve fact quality without adding open-ended rider questions.
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
| 8 | Location screen as default home | M6 |
| 9 | Quiet indicator on Map | M6 |
| 10 | Visual pass (typography, symbols, spacing) | 1–7 |
| 11 | Update ride test checklist for first-time flow | M4 checklist |
| 12 | App Review and privacy readiness notes | 1–7 |
| 13 | Info.plist background-mode audit | 1–7 |
| 14 | ElevenLabs proxy TTS with Apple fallback | Physical phone |
| 15 | Fact prompt/contract update for richer Short/Long Facts and home context | Proxy contract |
| 16 | Map-first Location layout with compact overlay and doubled default map area | M6 |
| 17 | Settings readability pass: high contrast, larger text, full-width hit targets, explicit rider-context labels | M6.5 |

### 5.3 Done criteria

- [ ] New rider can complete onboarding and start tracking without enabling debug settings.
- [ ] Location permission rationale is visible before the system prompt.
- [ ] Denied permission shows recovery UI, not a blank screen.
- [ ] Home tab shows current place and last announcement within one glance.
- [ ] Settings Simple section has ≤ 3 decision areas; Advanced holds debug and tuning.
- [ ] Location status row shows only actionable states; normal ride view does not display generic `Location is active`.
- [ ] Map zoom controls have a visibly larger, full-area hit target and consistent zoom-in/zoom-out behavior.
- [ ] Build metadata line appears beneath "MotoGuide" on main screen in test mode.
- [ ] Settings strings use consistent rider language and explicit labels for context inputs.
- [ ] Settings rows remain readable under glare/vibration assumptions: strong contrast, large type, full-width hit targets, and no placeholder-only labels.
- [ ] No rider-visible use of "geocode" or "Nation" without explanation.
- [ ] Default interval is 10 s; street off; Short Facts mode selected.
- [ ] Location screen is default with quiet banner when applicable.
- [ ] Simulator and device smoke test documented for first-time path.
- [ ] App Review and privacy risks are documented before broader external testing.
- [ ] Ready for the 2026-07-03 field trial without developer briefing.

---

## 6. Executive Summary

- MotoGuide works technically and has early product shape; the remaining MVP1 gap is field readiness.
- First-time riders need a clear story: **companion audio for place awareness**, not navigation, before the location permission dialog.
- **Must-have polish:** onboarding, permission copy, hide debug controls, rider language, live status, error states, confirmed defaults (10 s interval, Short Facts, no street).
- **Should-have:** complete Location home, History tab polish, basic visual consistency, Simple vs Advanced settings.
- **Defer:** deterministic place data, App Store launch polish, accounts, routing, CarPlay, boundary polygons, open-ended rider questions.
- Settings simplify to **Announcement style** + **What to announce**; everything else in Advanced.
- Code defaults for interval, content mode, and boundaries are already ride-sensible; main gaps are **permission timing** and **UI exposure**.
- Milestone 6.5 sits between Location completion (M6) and Field Trial (M8).
- Location screen (`MAP_SITUATIONAL_AWARENESS.md`) is the strongest single UX upgrade for "where am I" without competing with nav apps.
- Field trial on 2026-07-03 should test **ride value**, not confusion about toggles and jargon.

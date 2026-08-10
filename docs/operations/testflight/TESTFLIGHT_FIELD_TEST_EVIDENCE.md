# RideHorizon TestFlight Field-Test Evidence

Date: 2026-08-04

Status: **App Store Connect reports release candidate `0.12.4 (20260804.0246)` Complete and Ready to Submit. Do not invite external testers until the exact Internal TestFlight binary passes the mandatory stationary and field evidence gate.**

This is the operational evidence record for stationary, road and background testing. `ITEM-BACKLOG.md` remains the delivery-status authority; this document records what was tested, on which build, and with what result.

`docs/architecture/plans/AUDIO_INTEROPERABILITY_VALIDATION_PLAN.md` is the requirements and staged test-design authority for coexistence with YouTube Music, Google Maps and later audio apps. Record run results here; do not duplicate delivery status in that plan.

## Safety rules

- Configure the app, start music and navigation, and record results only while stopped.
- Do not capture screenshots, read diagnostics or change settings while moving.
- Stop the test if speech, volume changes, distraction, heat or any other behaviour feels unsafe.
- Use an ordinary familiar route and keep the normal navigation app in charge.
- A test is not passed by recollection alone. Record the build, device, conditions, observed result and supporting evidence.

## Original findings and implemented correction

Source review on 2026-08-02 confirmed two credible causes for the reported behaviour:

1. Ride tracking starts automatically after onboarding. With Always location permission, the app enables background location, disables automatic pausing and has no inactivity end condition.
2. The playback audio session is activated when the location manager is created and is not deactivated after speech. When music interruption is enabled, that long-lived session includes audio ducking.

These findings explained the symptoms. Development candidate `0.12.3 (20260803.0032)` replaces automatic tracking with an explicit bounded ride session and replaces app-lifetime audio ownership with playback-scoped ownership. These changes passed 144 physical-iPhone unit tests, signed build, install and launch. They still require the stationary and exact-TestFlight physical evidence below.

## Accepted ride-session decision

Use **Start ride** and **End ride** as the product verbs. Do not call the action “guiding”: RideHorizon is a companion, not a navigation system.

Accepted by Rob on 2026-08-02:

- Opening RideHorizon leaves it idle. It may obtain a foreground location fix for the map, but it does not begin continuous background tracking or activate the playback audio session.
- Tapping **Start ride** begins continuous tracking and announcements. Reopening the app during an active ride resumes the active-ride UI.
- Tapping **End ride** stops location updates, cancels pending work and speech, deactivates the audio session with notification to other audio apps, and returns the app to idle.
- If the accepted locations show less than 50 metres of displacement across a rolling 10-minute window, RideHorizon suspends announcements and asks **Still riding?** using an in-app alert when visible and a local notification when backgrounded.
- **Continue ride** resumes the active session. **End ride**, or no response within a proposed two-minute grace period, ends it. Movement exceeding 50 metres during the grace period cancels the timeout and resumes the ride.
- At Start ride and after each confirmed movement, retain an inactivity anchor. Accept only samples no more than 15 seconds old with a non-negative horizontal accuracy no worse than 30 metres. Confirm movement and reset the anchor/timer only when the straight-line anchor-to-sample distance minus both samples' horizontal-accuracy values is at least 50 metres. Do not use accumulated path length. If no sample proves movement for 10 elapsed minutes, including when accuracy remains poor, enter Awaiting Confirmation rather than tracking indefinitely.
- Request local-notification permission contextually on the first Start ride. If notification permission is denied, show the prompt while foregrounded but still end the ride after the two-minute grace period when backgrounded; a notification is helpful, not a prerequisite for bounded cleanup.

The app must not try to terminate its own process. “Shut down” means ending the ride session and releasing background location, network, timers and audio resources.

## What iOS can observe for audio diagnosis

RideHorizon can record its own audio-session lifecycle, output-volume snapshots, current audio route, interruptions, route changes, whether other audio is playing, and the system hint that secondary audio should be silenced. It cannot reliably identify Google Maps, Apple Maps, Calimoto or a music app by name, inspect their audio content, predict every external prompt, or set the iPhone’s system volume.

The diagnostic log should therefore record:

- ISO-8601 timestamp and elapsed time from ride start;
- ride state, app foreground/background state and location-tracking state;
- announcement queued, deferred, started, finished, cancelled or failed;
- speech provider and playback path, without recording spoken content;
- audio-session category, mode, options, activation and deactivation result;
- output-volume snapshot, current route and whether other audio is playing;
- interruption begin/end, silence-secondary-audio hint, route change and media-services reset;
- manual end, inactivity prompt, continuation and automatic end.

Shareable diagnostics must not contain precise location, API credentials, generated fact text or other apps’ content.

Candidate `0.12.3 (20260803.0032)` provides this Release-build ring buffer, capped at 2,000 events, seven days or 1 MiB, whichever limit is reached first. It uses `FileProtectionType.completeUntilFirstUserAuthentication`, is excluded from device backups, coalesces persistence away from the main actor, and provides view, export and clear actions under Advanced with stationary-use copy. The schema is typed and cannot accept coordinates, spoken text, credentials or external audio content.

## Automated and service evidence

### Current release candidate — 2026-08-04

- Release candidate: `0.12.4 (20260804.0246)`; bundle identifier `ai.digitalmercenaries.ridehorizon`; iPhone-only; arm64.
- All 177 `RideHorizonTests` passed on `Robert’s iPhone 17`, iPhone 17 Pro Max, iOS 26.5.2.
- The signed development build with the same version and build number installed and launched on the target iPhone.
- The proxy Gradle suite passed. Live Fly checks returned HTTP 200 for health, automatic restricted session, fact and Premium Voice; speech returned valid `audio/mpeg` data.
- Exact Release archive: `build/TestFlight/RideHorizon-0.12.4-20260804.0246.xcarchive`.
- The distribution IPA passed strict signature verification, has `beta-reports-active=true` and `get-task-allow=false`, contains a valid `PrivacyInfo.xcprivacy`, contains no test or calibration artefacts, and has matching binary/dSYM UUID `2F154D31-0285-319A-956C-0FDE75B5D775`.
- Xcode completed Apple server-side validation and reported `Upload succeeded` and `Uploaded package is processing.` on 2026-08-04. App Store Connect subsequently reported the upload **Complete** and the build **Ready to Submit**.
- Installation and human validation of the exact Internal TestFlight binary remain to be verified under RH-002.

### Superseded evidence

- Physical device: `Robert’s iPhone 17`, iPhone 17 Pro Max, iOS 26.5.2.
- `RideHorizonTests`: 144 passed, zero failed, zero skipped on 2026-08-03.
- Signed development build `0.12.3 (20260803.0032)`: built, installed and launched on the physical iPhone.
- Proxy Gradle suite: `BUILD SUCCESSFUL`.
- Live health, automatic restricted session, fact and Premium Voice requests: HTTP 200 on 2026-08-03; the fact contained 263 characters and speech returned `audio/mpeg`, 38,078 bytes.
- Product, support and privacy-policy URLs: HTTP 200 through the fixed-origin Cloudflare worker.
- Exact archive `0.12.3 (20260803.0032)`: re-signed by Xcode with the cloud-managed Apple Distribution certificate and App Store profile for `ai.digitalmercenaries.ridehorizon`.
- Apple server-side validation: passed at `2026-08-03T01:44:00+01:00` with no validation issues.
- Retained IPA: strict code signature passed; `beta-reports-active=true`; `get-task-allow=false`; iPhone-only; `PrivacyInfo.xcprivacy` present; SHA-256 `d435b14b2c6a7080fe82ad4f109e3da4e076072d3152000f50632eeb27157620`.
- App Store Connect upload: deliberately not started; the five stationary checks below remain the pre-upload safety gate.
- XCUITest did not execute: XCTest timed out while enabling automation mode on the physical device, and CoreSimulator services were unavailable. This is a test-harness blocker, not positive app evidence; use the human stationary rows below.
- Audio Increment 1 candidate `0.12.3 (20260803.2100)`: the complete `RideHorizonTests` target passed with zero failures on the physical iPhone; the signed build completed, installed and launched on 2026-08-03. Automated coverage includes a correlated fact-to-release export, activation failure, bounded release recovery, single restart, stale-restart prevention, non-resumable cancellation and active-speech supersession. Perceptual YouTube Music evidence remains outstanding.
- Timer-removal candidate `0.12.3 (20260803.2218)`: all 172 `RideHorizonTests` passed on the physical iPhone; signed Debug and Release builds succeeded; the Debug app installed and launched; the Fly health endpoint returned `ok`. Coverage includes timer-free preflight, overlapping observed audio intervals, media-services-reset recovery and privacy-safe network snapshots at fact/Premium Voice request stages. Perceptual YouTube Music evidence remains outstanding.

## Test run record

Create one record per candidate or materially different environment.

| Field | Value |
|---|---|
| Test run ID | `YYYY-MM-DD-initials-sequence` |
| App version and build | `0.12.3 (20260803.2218)` |
| Install source | Xcode |
| iPhone and iOS version | iPhone 17 Pro Max / iOS 26.5.2 |
| Headset and connection | |
| Music app/source | |
| Navigation app | |
| Route and approximate duration | |
| Weather/signal conditions | |
| Tester | |

Use `Not run`, `Pass`, `Fail` or `Blocked`. A pass needs the evidence named in the row.

### Manual stationary observation — 2026-08-03

This observation came from Rob during a clean-install/manual run while another development task was reinstalling builds. The precise installed build was therefore not confirmed and this record does not replace exact-build evidence for the release gate.

| Field | Value |
|---|---|
| Test run ID | `2026-08-03-RB-01` |
| App version and build | Unconfirmed Xcode development build |
| Install source | Xcode; concurrent reinstall activity |
| iPhone and iOS version | iPhone 17 Pro Max / iOS 26.5.2 |
| Tester | Rob |

| Area | Observed result | Assessment | Follow-up |
|---|---|---|---|
| Clean install and onboarding | Completed without crash or hang. Privacy details and the full public privacy-policy link worked. No invite code, proxy token, API key or other credential prompt appeared. RideHorizon naming was consistent. | Pass for the observed development build; exact TestFlight build remains required. | Onboarding and initial-screen usability findings are captured under RH-010. |
| Development Test Mode default | Test Mode was on after installation. | Expected for the current Debug testing campaign; not acceptable as the Release/TestFlight default. Existing build configuration is intended to default Release builds to off and must be verified on the exact TestFlight build. | RH-002 exact-build check. |
| Real-location start | With Test Mode off, the map immediately reached a plausible real position and displayed the current road. The active control changed to End Ride. No initial Apple Voice announcement occurred and no credential prompt appeared. Permission-prompt timing was inconclusive because another task was reinstalling the app. | Core foreground location behaviour observed. Contextual permission timing and diagnostic evidence remain unproved. | Retest TF-SESSION-02 on the exact build without concurrent installation. |
| Empty announcement state | Before any announcement, the sheet displayed “No spoken phrase yet” alongside repeat/stop instructions. | Non-blocking usability debt. | RH-010. |
| Manual end | End Ride returned the control to Start Ride. There was no positive acknowledgement that tracking had stopped. | Visible state transition observed, but resource cleanup was not evidenced. | RH-010 for acknowledgement; TF-SESSION-03 still requires the diagnostic log and location-indicator observation. |

### Manual Premium Voice observation — 2026-08-03

| Field | Value |
|---|---|
| Test run ID | `2026-08-03-RB-02` |
| App version and build | Unconfirmed Xcode development build |
| Conditions | Stationary; Wi-Fi; Test Mode; Road; Names Only; Premium Voice; no competing audio reported |
| Tester | Rob |

Three consecutive **Next Test Location** actions produced matching main-screen, spoken and log results in the expected order. Premium Voice succeeded every time without Apple Voice fallback. Speech was not missing, stale or duplicated at the event level. The visible location included Woolaston Court Cottage, Lydney, Gloucestershire, England and United Kingdom. One announcement said “Gloucestershire. Lydney, Gloucestershire.”, redundantly repeating the county; this is recorded as non-blocking wording defect RH-012. No logging defect was observed. Because the exact build was not confirmed, retain the exact-Internal-TestFlight smoke requirement.

## Mandatory pre-road tests

| ID | Test | Expected result | Evidence | Status |
|---|---|---|---|---|
| TF-INSTALL-01 | Clean install and onboarding | No invite code, token or credential prompt. Test Mode is off. Privacy link opens. | Screen recording or screenshots while stationary; build number | Not run |
| TF-SESSION-01 | Open the app after onboarding without starting a ride | App remains idle; no continuous/background location session and no active playback audio session | Diagnostic log plus iOS location indicator observation | Ready on installed `20260803.2218`; passed on superseded `20260803.0032` |
| TF-SESSION-02 | Tap Start ride while stationary | Ride state becomes active; the location permission request is contextual; location begins | Diagnostic log and screenshot | Ready on installed `20260803.2218`; passed on superseded `20260803.0032` |
| TF-SESSION-03 | Tap End ride | Location, pending requests, speech and timers stop; audio session deactivates; other audio remains at its prior level | Diagnostic log and short observation note | Ready on installed `20260803.2218`; passed on superseded `20260803.0032` |
| TF-AUDIO-01 | Preview Apple Voice and Premium Voice with no other audio | Both play once and finish cleanly; no session remains active afterwards | Diagnostic log and subjective loudness score | Ready on installed `20260803.2218`; passed on superseded `20260803.0032` |
| TF-AUDIO-02 | Play music, then trigger one Apple Voice announcement and one Premium Voice announcement | Music pauses only for each announcement and resumes smoothly within one second, with no sudden loud jump | Diagnostic export and observation note | Ready on installed `20260803.2218`; failed on superseded `20260803.0032` |
| TF-PROXY-01 | Exercise Premium Voice after an idle proxy period | Either Premium Voice succeeds within the retry ceiling or Apple Voice fallback occurs once; no late duplicate speech | Diagnostic log | Not run |

Do not begin the moving tests unless the session and audio pre-road tests pass.

## Mandatory field tests

| ID | Test | Expected result | Evidence | Status |
|---|---|---|---|---|
| TF-LOC-01 | Ride with RideHorizon foregrounded | Location and place changes remain plausible; announcements follow configured boundaries | Post-ride log and route notes | Not run |
| TF-LOC-02 | Lock the screen for at least 15 minutes during an active ride | The active ride continues without requiring interaction | Diagnostic log with screen-state markers | Not run |
| TF-LOC-03 | Put the navigation app in the foreground for at least 15 minutes | RideHorizon continues only while the ride is active and does not disrupt navigation | Diagnostic log and observation note | Not run |
| TF-AUDIO-03 | Ride with music playing and at least three RideHorizon announcements | Each announcement is intelligible; music pauses and resumes smoothly every time | Event log and per-event notes | Ready for exact-build field test |
| TF-AUDIO-04 | Exercise navigation prompts before, during and after pending RideHorizon announcements | RideHorizon defers or pauses only when iOS emits an observed interruption or secondary-audio begin notification. It restarts once, immediately after every overlapping observed interval ends, with no settling timer. A preflight hint alone must not delay speech. Record overlap with no corresponding OS event as residual platform evidence. | Timestamped event log and observation note | Hold until the YouTube Music gate passes |
| TF-AUDIO-05 | Compare Apple Voice and Premium Voice with normal music and navigation volume | Both are intelligible without increasing system volume to a level that makes music/navigation unsafe | 1–5 intelligibility score for each provider and notes | Ready for exact-build field test |
| TF-AUDIO-06 | Disconnect and reconnect the Bluetooth headset during an active ride while safely stopped | Route change is handled; no blast, stuck interruption, duplicate speech or lost long-term audio | Diagnostic log and observation note | Ready for exact-build field test |
| TF-NET-01 | Pass through weak or absent mobile data | Requests remain bounded; transient failures retry rationally; stale speech never arrives after the context has changed | Diagnostic log with public network-path classification plus operator conditions; do not claim cellular dBm or signal bars | Not run |
| TF-POWER-01 | Complete a 60-minute ride with screen mostly off | No abnormal heat, obvious runaway background activity or unacceptable battery drain | Start/end battery percentage, screen state and temperature note | Not run |

## Mandatory inactivity and end-of-ride tests

| ID | Test | Expected result | Evidence | Status |
|---|---|---|---|---|
| TF-IDLE-01 | Remain within 50 metres for 10 minutes during an active ride | Announcements suspend and **Still riding?** appears as an alert or local notification | Diagnostic log and notification screenshot after stopping | Ready for exact-build field test |
| TF-IDLE-02 | Tap Continue ride during the grace period | The same ride resumes without duplicate requests or announcements | Diagnostic log | Ready for exact-build field test |
| TF-IDLE-03 | Do not respond during the grace period | The ride ends after the configured grace period; background location and audio activity stop | Diagnostic log and iOS location-indicator observation | Ready for exact-build field test |
| TF-IDLE-04 | Move more than 50 metres during the grace period | Timeout is cancelled and the ride resumes without interaction | Diagnostic log and route note | Ready for exact-build field test |
| TF-IDLE-05 | Stop in traffic, at fuel, or at a café; include poor GPS accuracy | GPS drift does not keep the ride alive indefinitely; a genuine resumed ride can be continued safely | Diagnostic log with accuracy values but no coordinates | Ready for exact-build field test |
| TF-END-01 | End the ride, lock the phone and leave it for at least 15 minutes | No further location, network, speech or audio-session events occur | Diagnostic log and iOS location-indicator observation | Ready for exact-build field test |
| TF-END-02 | Reopen RideHorizon after a manual or automatic end | The app is idle and requires Start ride; it does not silently restart tracking | Diagnostic log and screenshot | Ready for exact-build field test |

## Defect and evidence submission

For every failure, add one entry below and retain the original evidence.

| Test ID | Run ID | Result | Expected | Observed | Evidence path/link | Backlog or issue reference | Retest build/result |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

## Release evidence gate

External TestFlight invitations remain blocked until:

- all mandatory pre-road tests pass on the exact uploaded build;
- all mandatory field, inactivity and end-of-ride tests pass on the same build or an approved replacement;
- no unresolved failure can cause distracting audio, a sudden volume increase, failure to honour an observable iOS audio interruption, unbounded background location, a crash or a credential prompt;
- `docs/operations/testflight/TESTFLIGHT_PRIVATE_BETA_PACK.md` administrative gates are complete;
- Rob records the explicit milestone decision: **continue**, **revise**, **refactor**, **research**, **prototype**, **reduce scope**, **pause** or **stop**.

This evidence format follows [SOP: Adaptive Agentic Software Delivery v1.2](https://app.notion.com/p/3aea4c502b1781a888b1f8e851697813), reviewed on 2026-08-02. Recheck that source if its version or current date changes materially.

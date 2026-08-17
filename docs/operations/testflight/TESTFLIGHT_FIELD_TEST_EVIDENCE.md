# RideHorizon TestFlight Field-Test Evidence

Date: 2026-08-17

Status: **The latest locally verified automated rebuild `0.12.4 (20260806.221234)` is `VALID`, permanently `INTERNAL_ONLY`, `IN_BETA_TESTING` and assigned to the internal beta group. Its SHA-256-protected receipt records `ready_for_internal_tester` and an installed tester state. That state does not prove which binary is installed on the phone: exact in-app build-display confirmation and all build-specific physical evidence remain unverified, and evidence from earlier builds must not be transferred to it.**

Stationary execution protocol: [`../../testing/STATIONARY_PHYSICAL_TEST_PROTOCOL.md`](../../testing/STATIONARY_PHYSICAL_TEST_PROTOCOL.md). Owner road-test execution protocol: [`RIDE_UAT_PROTOCOL.md`](RIDE_UAT_PROTOCOL.md). This evidence document remains the authoritative run record and coverage matrix; the two protocols contain execution method only and do not carry competing results.

This is the operational evidence record for stationary, road and background testing. Backlog.md CLI records remain the delivery-status authority; this document records what was tested, on which build, and with what result.

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

### Latest automated TestFlight Internal Only deployment — 2026-08-06

- Candidate: `0.12.4 (20260806.221234)`; bundle identifier `ai.digitalmercenaries.ridehorizon`; production scheme `RideHorizon`; iPhone arm64 archive.
- Command: `./tools/ios-testflight deploy`.
- No app source or project input changed after the 182-test, zero-failure evidence run. The deployment used the audited owner override bound to tested-input fingerprint `1eb3727da0d16c8d92a19b3b2ff67472111a62b5b1aec5c68b77728da5608b29`; the script revalidated the same fingerprint after archiving.
- Archive verification passed for bundle, version, team, executable arm64, Apple signature, provisioning and release resources.
- Xcode cloud-signed and uploaded the build as permanently TestFlight Internal Only. App Store Connect then reported the exact build `VALID`, audience `INTERNAL_ONLY` and beta state `IN_BETA_TESTING`.
- The exact build is attached to `RideHorizon team`; the configured tester account is present and active in that group.
- Timings: archive 32 seconds; upload 46 seconds; Apple processing 111 seconds; readiness verification 4 seconds; total 203 seconds.
- Machine-readable receipt: `.git/ios-testflight/receipts/RideHorizon-0.12.4-20260806.221234.json`; its companion SHA-256 matched on 2026-08-17.
- Remaining exact-build gate: install or update from TestFlight on the target iPhone, then open RideHorizon **Settings** while stopped and verify `0.12.4 (20260806.221234)`. The receipt's tester state does not prove installation of this exact build.

### No-code TestFlight rebuild — 2026-08-06

- Candidate: `0.12.4 (20260806.1500)`; bundle identifier `ai.digitalmercenaries.ridehorizon`; production scheme `RideHorizon`; iPhone arm64 archive.
- No source or project configuration was edited for this rebuild. `CURRENT_PROJECT_VERSION=20260806.1500` was supplied as an `xcodebuild` command-line override so Apple received a unique build while the existing working-tree candidate remained unchanged.
- The complete `RideHorizonTests` simulator suite passed: 182 tests, zero failures. The exact command used build number `20260806.1500` and returned `** TEST SUCCEEDED **`.
- The unsigned generic-iPhone Release check returned `** BUILD SUCCEEDED **`. The signed production archive returned `** ARCHIVE SUCCEEDED **` and contained version `0.12.4`, build `20260806.1500`, bundle identifier `ai.digitalmercenaries.ridehorizon`, team `W64ZN45B4A`, scheme `RideHorizon` and architecture `arm64`.
- Xcode Organizer reported `App upload complete` and then `Uploaded to Apple` at 2026-08-06 15:05 Europe/London. No authentication, certificate or Keychain interaction was requested.
- App Store Connect showed upload status `Complete`, TestFlight status `Ready to Submit`, internal group `RideHorizon team` and one internal invite. `Ready to Submit` is the external-testing state; internal assignment is present.
- Remaining exact-build gate: refresh TestFlight on the target iPhone, install `0.12.4 (20260806.1500)`, then open RideHorizon **Settings** while stopped and verify that the displayed version/build matches before running or transferring any physical evidence.

### Build-identity replacement candidate — 2026-08-06

- Candidate: `0.12.4 (20260806.1229)`; bundle identifier `ai.digitalmercenaries.ridehorizon`; production scheme `RideHorizon`; iPhone arm64 archive.
- Settings now displays `RideHorizon v0.12.4` and `build 2026-08-06T12:29Z`, derived at runtime from `CFBundleShortVersionString` and `CFBundleVersion`. No manually duplicated release identity was added.
- An unsigned generic-iPhone Release build completed with `** BUILD SUCCEEDED **` using `xcodebuild build -project RideHorizon.xcodeproj -scheme RideHorizon -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/ridehorizon-version-derived CODE_SIGNING_ALLOWED=NO`.
- Xcode initially had the internal `RideHorizonCalibration` scheme active. That scheme deliberately has `buildForArchiving = NO`, so Product → Archive was unavailable. Selecting `RideHorizon` with `Any iOS Device (arm64)` enabled Archive without changing account, certificate or project signing configuration.
- Xcode Organizer created the exact archive, showed team `Digital Mercenaries Ltd`, bundle identifier `ai.digitalmercenaries.ridehorizon`, version/build `0.12.4 (20260806.1229)` and architecture `arm64`, then completed App Store Connect upload at 2026-08-06 14:22 Europe/London. Organizer reports `Uploaded to Apple` and build number `20260806.1229`.
- Xcode used the normal Organizer distribution path and cloud-managed App Store signing. The local certificate list showing only Apple Development did not prevent upload. A sandboxed command-line export had incorrectly suggested `No Accounts`; the healthy Xcode Apple Accounts view and successful Organizer upload proved that was not an account failure.
- No complete iOS test-suite, physical-device install, App Store Connect processing, internal-group assignment or exact-TestFlight check has yet been recorded for this replacement candidate. Do not call it ready for installation until those gates are run.
- The canonical operating procedure is [SOP: iOS Build and TestFlight Deployment v1.0](https://app.notion.com/p/3b4a4c502b1781e18977d4e2d9b75c74). `AGENTS.md` now requires agents to fetch it before iOS build, archive, signing, upload or release diagnosis.

### Continuation checkpoint — reconciled 2026-08-17

- The local protected receipt proves processing and internal-group readiness for `0.12.4 (20260806.221234)` as observed on 2026-08-06. No live App Store Connect query was made during this reconciliation.
- Install or update to that exact build from TestFlight. In RideHorizon, open **Settings** while stopped and confirm the displayed version/build is `0.12.4 (20260806.221234)`. Record the observation in this file before transferring any stationary or road evidence to the replacement candidate.
- Then run the stationary and owner-road protocols already linked below. Do not invite external testers or mark RH-002 complete until the replacement build has its own installation, build-identity, Bluetooth/audio, background/inactivity and ride evidence.
- If Archive is unavailable during a later release, first inspect Xcode's visible **Active Scheme** and **Active Run Destination**. The expected production combination is `RideHorizon` plus `Any iOS Device (arm64)`. Do not sign out of the Apple account or alter certificates based only on a sandboxed command-line export error.

### Earlier release candidate — 2026-08-04

- Release candidate: `0.12.4 (20260804.0246)`; bundle identifier `ai.digitalmercenaries.ridehorizon`; iPhone-only; arm64.
- All 177 `RideHorizonTests` passed on `Robert’s iPhone 17`, iPhone 17 Pro Max, iOS 26.5.2.
- The signed development build with the same version and build number installed and launched on the target iPhone.
- The proxy Gradle suite passed. Live Fly checks returned HTTP 200 for health, automatic restricted session, fact and Premium Voice; speech returned valid `audio/mpeg` data.
- Exact Release archive: `build/TestFlight/RideHorizon-0.12.4-20260804.0246.xcarchive`.
- The distribution IPA passed strict signature verification, has `beta-reports-active=true` and `get-task-allow=false`, contains a valid `PrivacyInfo.xcprivacy`, contains no test or calibration artefacts, and has matching binary/dSYM UUID `2F154D31-0285-319A-956C-0FDE75B5D775`.
- Xcode completed Apple server-side validation and reported `Upload succeeded` and `Uploaded package is processing.` on 2026-08-04. App Store Connect subsequently reported the upload **Complete** and the build **Ready to Submit**.
- The exact binary installed and launched through Internal TestFlight. Owner moving-road validation remains to be recorded under RH-002.

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
| Protocol | Stationary Physical-Test Protocol or Owner Ride UAT Protocol, as applicable |
| App version and build | `0.12.4 (20260806.221234)` |
| Install source | Internal TestFlight |
| iPhone and iOS version | iPhone 17 Pro Max / iOS 26.5.2 |
| Headset and connection | |
| Music app/source | |
| Navigation app | |
| Broad test area and approximate duration | Do not commit the exact route or personal location history. |
| Pre-sampled transition or expected hierarchy | |
| Weather/signal conditions | |
| Stopped feedback-capture method and lock result | |
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

## Mandatory exact-build stationary tests

Use [`../../testing/STATIONARY_PHYSICAL_TEST_PROTOCOL.md`](../../testing/STATIONARY_PHYSICAL_TEST_PROTOCOL.md). The X-COM2 setup guide is a one-time configuration prerequisite only; record its locked/unlocked feedback-capture limitation as test-operability context, not as RideHorizon product evidence. For `TF-AUDIO-01`, record phone-only provider behaviour and X-COM2 playback separately; a Pass requires the stated helmet result.

| ID | Test | Expected result | Evidence | Status |
|---|---|---|---|---|
| TF-INSTALL-01 | Clean install and onboarding | No invite code, token or credential prompt. Test Mode is off. Privacy link opens. | Screen recording or screenshots while stationary; build number | Not run |
| TF-SESSION-01 | Open the app after onboarding without starting a ride | App remains idle; no continuous/background location session and no active playback audio session | Diagnostic log plus iOS location indicator observation | Ready on installed `20260803.2218`; passed on superseded `20260803.0032` |
| TF-SESSION-02 | Tap Start ride while stationary | Ride state becomes active; the location permission request is contextual; location begins | Diagnostic log and screenshot | Ready on installed `20260803.2218`; passed on superseded `20260803.0032` |
| TF-SESSION-03 | Tap End ride | Location, pending requests, speech and timers stop; audio session deactivates; other audio remains at its prior level | Diagnostic log and short observation note | Ready on installed `20260803.2218`; passed on superseded `20260803.0032` |
| TF-AUDIO-01 | Preview Apple Voice and Premium Voice with no other audio | Both play once and finish cleanly; no session remains active afterwards | Diagnostic log and subjective loudness score | Ready on installed `20260803.2218`; passed on superseded `20260803.0032` |
| TF-AUDIO-02 | Play music, then trigger one Apple Voice announcement and one Premium Voice announcement | Music pauses only for each announcement and resumes smoothly within one second, with no sudden loud jump | Diagnostic export and observation note | Ready on installed `20260803.2218`; failed on superseded `20260803.0032` |
| TF-AUDIO-06 | Disconnect and reconnect the Bluetooth headset during an active ride while safely stopped | Route change is handled; no blast, stuck interruption, duplicate speech or lost long-term audio | Diagnostic log and observation note | Ready for exact-build stationary test |
| TF-PROXY-01 | Exercise Premium Voice after an idle proxy period | Either Premium Voice succeeds within the retry ceiling or Apple Voice fallback occurs once; no late duplicate speech | Diagnostic log | Not run |

Do not begin the moving tests unless the session and audio pre-road tests pass.

## Mandatory moving-road tests

| ID | Test | Expected result | Evidence | Status |
|---|---|---|---|---|
| TF-LOC-01 | Ride with RideHorizon foregrounded | Location and place changes remain plausible; announcements follow configured boundaries | Post-ride log and route notes | Not run |
| TF-LOC-02 | Lock the screen for at least 15 minutes during an active ride | The active ride continues without requiring interaction | Diagnostic log with screen-state markers | Not run |
| TF-LOC-03 | Put the navigation app in the foreground for at least 15 minutes | RideHorizon continues only while the ride is active and does not disrupt navigation | Diagnostic log and observation note | Not run |
| TF-AUDIO-03 | Ride with music playing and at least three RideHorizon announcements | Each announcement is intelligible; music pauses and resumes smoothly every time | Event log and per-event notes | Ready for exact-build field test |
| TF-AUDIO-04 | Exercise navigation prompts before, during and after pending RideHorizon announcements | RideHorizon defers or pauses only when iOS emits an observed interruption or secondary-audio begin notification. It restarts once, immediately after every overlapping observed interval ends, with no settling timer. A preflight hint alone must not delay speech. Record overlap with no corresponding OS event as residual platform evidence. | Timestamped event log and observation note | Hold until the YouTube Music gate passes |
| TF-AUDIO-05 | Compare Apple Voice and Premium Voice with normal music and navigation volume | Both are intelligible without increasing system volume to a level that makes music/navigation unsafe | 1–5 intelligibility score for each provider and notes | Ready for exact-build field test |
| TF-NET-01 | Pass through weak or absent mobile data | Requests remain bounded; transient failures retry rationally; stale speech never arrives after the context has changed | Diagnostic log with public network-path classification plus operator conditions; do not claim cellular dBm or signal bars | Not run |
| TF-POWER-01 | Complete a 60-minute ride with screen mostly off | No abnormal heat, obvious runaway background activity or unacceptable battery drain | Start/end battery percentage, screen state and temperature note | Not run |

## Mandatory stationary inactivity and end-of-ride tests

| ID | Test | Expected result | Evidence | Status |
|---|---|---|---|---|
| TF-IDLE-01 | Remain within 50 metres for 10 minutes during an active ride | Announcements suspend and **Still riding?** appears as an alert or local notification | Diagnostic log and notification screenshot after stopping | Ready for exact-build field test |
| TF-IDLE-02 | Tap Continue ride during the grace period | The same ride resumes without duplicate requests or announcements | Diagnostic log | Ready for exact-build field test |
| TF-IDLE-03 | Do not respond during the grace period | The ride ends after the configured grace period; background location and audio activity stop | Diagnostic log and iOS location-indicator observation | Ready for exact-build field test |
| TF-IDLE-04 | Move more than 50 metres during the grace period | Timeout is cancelled and the ride resumes without interaction | Diagnostic log and route note | Ready for exact-build field test |
| TF-IDLE-05 | Stop in traffic, at fuel, or at a café; include poor GPS accuracy | GPS drift does not keep the ride alive indefinitely; a genuine resumed ride can be continued safely | Diagnostic log with accuracy values but no coordinates | Ready for exact-build field test |
| TF-END-01 | End the ride, lock the phone and leave it for at least 15 minutes | No further location, network, speech or audio-session events occur | Diagnostic log and iOS location-indicator observation | Ready for exact-build field test |
| TF-END-02 | Reopen RideHorizon after a manual or automatic end | The app is idle and requires Start ride; it does not silently restart tracking | Diagnostic log and screenshot | Ready for exact-build field test |

## Historical owner ride UAT — 2026-08-06

### Test run record

| Field | Value |
|---|---|
| Test run ID | `2026-08-06-RB-01` |
| Protocol | Owner Ride UAT Protocol |
| App version and build | Provisionally recorded as `0.12.4 (20260804.0246)` from the retained local TestFlight archive; the app did not expose its installed build number. |
| Install source | Internal TestFlight, as assumed for this UAT; not independently confirmed in-app. |
| iPhone and iOS version | iPhone 17 Pro Max / iOS 26.5.2, from the current candidate record. |
| Headset and connection | X-COM2 Bluetooth headset. |
| Music app/source | YouTube Music. |
| Navigation app | Google Maps. |
| Phone/power | Quad Lock mounted; charger switched off; 44% at start and 25% after the main ride; later 10% while stationary, when charging was enabled; rider reported normal temperature. |
| Broad test area and approximate duration | Broad London/Surrey border area; main ride 55m 03s; later Bluetooth-route test 7m 17s; later place-display, locked-screen and inactivity session 73m 42s. No exact route or coordinates retained. |
| Tester | Rob |

### Results and evidence

| ID | Result | Observation | Diagnostic correlation | Assessment |
|---|---|---|---|---|
| RUAT3-01 | Fail | Before the Bluetooth test, with RideHorizon backgrounded and Google Maps foregrounded, the rider reported missing announcements at plausible place transitions, both without music and with YouTube Music. Repeating a crossing after bringing RideHorizon to the foreground produced an announcement. Bluetooth disconnection/reconnection later made no change to that pre-existing behaviour. During the later locked-screen test, no speech audio was heard at plausible place transitions. No unsafe or distracting behaviour was reported. | The Bluetooth-route session records a background `speechAudioReady` at `2026-08-06T17:10:23Z`, followed by `audioSessionActivationFailed` and `audioPlaybackCancelled`; a later foreground announcement played from `2026-08-06T17:11:23Z` to `2026-08-06T17:11:47Z`. In the locked-screen session, two background announcements repeated that chain at `2026-08-06T17:39:06Z` and `2026-08-06T17:40:20Z`; after RideHorizon entered the foreground, playback completed from `2026-08-06T17:42:16Z` to `2026-08-06T17:42:38Z`. | Observation: announcements were missing with navigation foregrounded and while the phone was locked, but were present after foregrounding RideHorizon. Inference: the repeated ready → activation-failed → cancelled chain is correlated with the missing speech. Bluetooth reconnection is not implicated, and no root cause is assigned. |
| RUAT3-02 | Fail, with positive coexistence evidence | In the initial foreground scenarios, music paused and resumed smoothly, Google Maps remained usable and no volume blast, stuck suppression or duplicate speech occurred. Later, RideHorizon speech was quieter than music/navigation, Premium Voice audibly fell back to Apple Voice with poor pronunciation, and one RideHorizon announcement was cut off when a newer RideHorizon announcement replaced it. | Six navigation interruption/restart pairs occur in the main ride. The later export contains 24 `premiumVoice` `playbackFailed` events, each followed by Apple `speechAudioReady`. At `2026-08-06T18:13:16Z`, Apple fallback playback began; `announcementSuperseded` and `audioPlaybackCancelled` followed at `2026-08-06T18:13:23Z`; replacement Apple playback then ran from `2026-08-06T18:13:25Z` to `2026-08-06T18:13:44Z`. | Music/navigation coexistence and Bluetooth recovery were positive. Overall fail because intelligibility and uninterrupted, appropriately ordered RideHorizon speech did not remain acceptable throughout the ride. |
| RUAT3-03 | Not observed | No naturally observed weak-data period was reported. | Diagnostics were exported but this run makes no claim about weak-data recovery. | No result. Do not seek poor reception. |
| RUAT3-04 | Partial | Main ride battery fell from 44% to 25% with the unpowered phone mounted in a Quad Lock. Later, at 10% while stationary, charging was enabled. The rider reported normal temperature and no later degradation. | Diagnostics show the main ride ran for 55m 03s and the later session for 73m 42s. | Thermal observation is positive. The later session included charging and the uninterrupted unplugged portion was under 60 minutes, so this is not a battery-drain pass. |
| TF-AUDIO-06 | Partial | While safely stopped, the rider switched the X-COM2 off, then reconnected it. No blast, stuck audio or duplicate speech was perceived. The pre-existing normal-navigation-foreground missing-announcement behaviour was unchanged. | The Bluetooth-route session records a route change to `Speaker` at `2026-08-06T17:08:48Z` and return to `BluetoothA2DPOutput` at `2026-08-06T17:09:20Z`. | Route recovery was safe and did not alter the separate RUAT3-01 behaviour. |
| TF-IDLE-01 / TF-IDLE-02 | Observed incidentally | While stopped, the rider saw **Still riding?** and continued the ride. | `rideInactivityPrompted` at `2026-08-06T16:59:40Z`; `rideContinued` 44 seconds later at `2026-08-06T17:00:24Z`. | The prompt and continuation are evidenced. This was not a deliberately controlled 10-minute stationary test, so it does not close the formal rows. |
| TF-IDLE-01 / TF-IDLE-03 | Partial / Pass | Stationary after the ride, the rider left the RideHorizon ride active and locked the phone. The rider did not notice a **Still riding?** notification and found the ride already stopped after returning approximately 15 minutes later. | In the background, `rideInactivityPrompted` occurred at `2026-08-06T18:43:44Z`; `rideEnded` followed exactly two minutes later at `2026-08-06T18:45:44Z`, with ride state idle and location tracking false. | TF-IDLE-03 passes for unattended automatic end. TF-IDLE-01 remains only partial: diagnostics prove that prompting was triggered, not that iOS displayed a visible notification; the rider's non-observation does not prove non-delivery. |
| TF-END-01 | Not run | Earlier End Ride transitions were recorded. For the intended stationary observation, the rider left the RideHorizon ride active before locking the phone, so this did not exercise post-end quiescence. | `rideEnded` at `2026-08-06T17:00:30Z` for the main ride and at `2026-08-06T17:14:45Z` for the Bluetooth-route ride, both with location tracking false. The stationary session ended automatically only after the locked wait. | End transitions are evidenced, but the required 15-minute period beginning after manual End Ride remains outstanding. |
| TF-END-02 | Pass after automatic end | On returning to RideHorizon, the rider found the ride stopped rather than silently restarted. | After `rideEnded`, the export records only foreground lifecycle events at `2026-08-06T18:50:37Z` and `2026-08-06T18:50:52Z`; ride state remained idle and location tracking false. | Automatic end returned the app to idle as intended. This does not substitute for TF-END-01 because the phone was locked before, rather than after, ride end. |
| Place-label display and speech | Observed, positive but provisional | Across several safely observed place changes, the rider reported that both displayed and spoken sub-locality behaviour worked well. The rider did not consider every detected boundary intuitively aligned with local knowledge; boundary-policy review is deferred until broader user feedback. | Supporting screenshots show raw Apple place fields, RideHorizon Current place and Last spoken phrase. They are retained only in this UAT chat; no address, exact route or coordinates are copied into this record. | Positive evidence for display/speech agreement across several samples. It does not establish that Apple field boundaries or RideHorizon place-selection policy match every rider's preferred local geography. |

### Evidence retained

- Rider notes in this UAT chat, recorded from `2026-08-06T17:17:52+01:00` to `2026-08-06T19:35:06+01:00`, plus answers resolving the speech-interruption, sub-locality and inactivity ambiguities.
- Four rider-attached Release diagnostic exports in this UAT chat, including the final export after automatic inactivity end. The exports contain no retained coordinates, route, spoken text or credentials.
- Supporting screenshots retained only in this UAT chat. Identifiable addresses, exact routes, coordinates and Apple region values are intentionally excluded from this repository record.

## Findings awaiting triage

For today's owner ride, retain every result and finding here. Do not create a GitHub issue or mutate Backlog.md tasks during the UAT session. Apply [SEERS — Standardised Bug Reporting](https://app.notion.com/p/322a4c502b1781e9873cd3008281d9f6) and retain the original evidence.

| Finding ID | Test/run | S — evidence | E — environment | E — expected | E — actual | R — reproduction/time | S — severity | Triage decision |
|---|---|---|---|---|---|---|---|---|
| | | | | | | | | Awaiting triage |
| RH-UAT-2026-08-06-01 | RUAT3-01; `2026-08-06-RB-01` | Rider notes and diagnostic exports. Repeated chains show `speechAudioReady` followed immediately by `audioSessionActivationFailed` and `audioPlaybackCancelled` while RideHorizon was backgrounded; later foregrounded announcements played to completion. | Provisional TestFlight `0.12.4 (20260804.0246)`; iPhone 17 Pro Max / iOS 26.5.2; X-COM2 Bluetooth; Google Maps foreground or phone locked; YouTube Music either absent or playing; Quad Lock mount; broad London/Surrey border area. | During an active ride, RideHorizon continues to deliver plausible announcements while navigation is foregrounded and while the phone is locked, with or without normal music. | No announcement was heard at reported plausible transitions while RideHorizon was backgrounded, including during the locked-screen test. After foregrounding RideHorizon, announcements were heard and completed. Bluetooth reconnection made no change to this pre-existing behaviour. | Reported at approximately `2026-08-06T17:17:52+01:00`, `2026-08-06T17:23:26+01:00`, `2026-08-06T17:52:56+01:00` and `2026-08-06T18:41:13+01:00`. Diagnostic examples: background ready → activation failed → cancelled at `2026-08-06T17:10:23Z`, `2026-08-06T17:39:06Z` and `2026-08-06T17:40:20Z`; foreground playback started at `2026-08-06T17:11:23Z` and `2026-08-06T17:42:16Z`. | Major | Awaiting triage. Observation and diagnostic correlation recorded; no root cause assigned. |
| RH-UAT-2026-08-06-02 | RUAT3-02; `2026-08-06-RB-01` | Rider observation in this UAT chat. | Provisional TestFlight `0.12.4 (20260804.0246)`; iPhone 17 Pro Max / iOS 26.5.2; X-COM2 Bluetooth; Google Maps and YouTube Music at the rider's normal volumes; broad London/Surrey border area. | RideHorizon synthesised speech audio is intelligible at a safe normal system volume alongside ordinary music and navigation prompts. | The rider judged RideHorizon synthesised speech audio quieter than both YouTube Music and Google Maps announcements. | Observed during the owner ride; no controlled loudness score or calibrated external comparison was collected. | Major | Awaiting triage. Observation only; no technical cause inferred. |
| RH-UAT-2026-08-06-03 | Place-label screen; `2026-08-06-RB-01` | Two screenshots retained in this UAT chat show the bottom-sheet layout at its initial and raised positions. | Provisional TestFlight `0.12.4 (20260804.0246)`; iPhone 17 Pro Max / iOS 26.5.2; portrait; RideHorizon idle; exact place intentionally omitted. | The Location bottom sheet preserves a complete lower edge at every supported detent and covers the lower screen without an unexplained map gap. | At the initial position, the lower sheet content was truncated. After swiping it upward, a gap appeared below the sheet, exposing the map. | While safely stopped, open the Location screen with Apple Place Data visible, then compare the initial sheet position with the raised sheet position; observed at approximately `2026-08-06T18:27:00+01:00`. | Minor | Awaiting triage. Visual observation only; no layout cause inferred. |
| RH-UAT-2026-08-06-04 | Place-label screen; `2026-08-06-RB-01` | Two screenshots retained in this UAT chat show the raw Apple `Sub-locality`, `Locality` and RideHorizon `Current place` fields. Identifiable location detail is not copied here. | Provisional TestFlight `0.12.4 (20260804.0246)`; iPhone 17 Pro Max / iOS 26.5.2; portrait; RideHorizon idle. | Current place should remain understandable to a rider and must not claim that an optional Apple placemark field has a guaranteed UK administrative or containment hierarchy. | The raw Apple sub-locality and locality appeared contrary to the rider's expected local hierarchy. RideHorizon displayed sub-locality as Current place by fixed precedence. | While safely stopped, expand Apple Place Data and compare the raw fields with Current place; observed at approximately `2026-08-06T18:27:00+01:00`. | Minor | Awaiting triage. Observation: raw field values and fixed app precedence. Inference: Apple placemark fields are descriptive rather than a guaranteed UK hierarchy; confirm against a broader corpus before changing selection or speech policy. |
| RH-UAT-2026-08-06-05 | RUAT3-02; `2026-08-06-RB-01` | Rider notes at `2026-08-06T19:14:24+01:00` and `2026-08-06T19:15:20+01:00`, confirmed as two descriptions of one incident; final diagnostic export. | Provisional TestFlight `0.12.4 (20260804.0246)`; iPhone 17 Pro Max / iOS 26.5.2; X-COM2 Bluetooth; RideHorizon foreground; broad London/Surrey border area. | RideHorizon speech already playing is completed or replaced according to a rider-safe, understandable policy without a rapid, unexplained cut-off. | A road-related announcement began, was cut off before completion, and was followed by a newer RideHorizon announcement rather than the first being queued to finish. | Apple fallback playback started at `2026-08-06T18:13:16Z`; a newer context superseded and cancelled it seven seconds later; replacement playback started at `2026-08-06T18:13:25Z` and finished at `2026-08-06T18:13:44Z`. Release diagnostics omit the announcement words, so the road wording remains rider observation. | Major | Awaiting triage. Observation and event correlation recorded; whether supersession or bounded queueing is the intended policy requires product review. |
| RH-UAT-2026-08-06-06 | RUAT3-02; `2026-08-06-RB-01` | Rider heard Premium Voice change to Apple Voice and judged the fallback pronunciation poor; final diagnostic export. | Provisional TestFlight `0.12.4 (20260804.0246)`; iPhone 17 Pro Max / iOS 26.5.2; X-COM2 Bluetooth; cellular data; later field session. | The selected Premium Voice remains available, or any fallback remains clear and acceptably pronounced without an unexplained change of voice. | Premium Voice repeatedly fell back audibly to Apple Voice; the rider found Apple pronunciation unacceptable. | The final export contains 24 `premiumVoice` `playbackFailed` events from `2026-08-06T17:51:56Z` to `2026-08-06T18:27:17Z`, each followed by Apple `speechAudioReady` for the same announcement. | Major | Awaiting triage. Provider failure and fallback are diagnostic facts; pronunciation quality is rider observation. Root cause not assigned. |
| RH-UAT-2026-08-06-07 | Location sheet; `2026-08-06-RB-01` | Rider note and supporting screenshots retained in this UAT chat; identifiable place data is excluded here. | Provisional TestFlight `0.12.4 (20260804.0246)`; iPhone 17 Pro Max / iOS 26.5.2; portrait; Location sheet expanded while safely stopped. | The initial useful sheet position exposes enough diagnostic Apple place data for efficient field review and evidence capture. | The rider needed several screenshots to capture the diagnostic place data and requested a slightly larger useful content area. | Safely stopped at approximately `2026-08-06T18:37:39+01:00`, open Apple Place Data and assess how much is visible without repeatedly changing the sheet position. | Minor | Awaiting triage. Product/UI request distinct from the sheet truncation and bottom-gap defect. |
| RH-UAT-2026-08-06-08 | Location sheet; `2026-08-06-RB-01` | Rider note and supporting screenshot retained in this UAT chat. | Provisional TestFlight `0.12.4 (20260804.0246)`; iPhone 17 Pro Max / iOS 26.5.2; portrait; Location sheet raised while safely stopped. | When the sheet changes height, the current-location marker remains centred within the map area still visible above it. | The rider observed that the location was not centred in the remaining visible map area after raising the sheet. | Safely stopped at approximately `2026-08-06T19:09:04+01:00`, raise the Location sheet and observe the marker in the uncovered map area. | Minor | Awaiting triage. Visual/product observation only; no layout or camera cause inferred. |
| RH-UAT-2026-08-06-09 | TF-IDLE-01 / TF-IDLE-03; `2026-08-06-RB-01` | Rider did not notice a **Still riding?** notification while the phone was locked and later found the ride automatically ended; final diagnostic export. | Provisional TestFlight `0.12.4 (20260804.0246)`; iPhone 17 Pro Max / iOS 26.5.2; phone locked; RideHorizon backgrounded; rider stationary after the ride. | The inactivity prompt is conspicuous enough for a locked-phone rider to continue the ride during the grace period when appropriate. | The rider did not notice a prompt or notification. RideHorizon automatically ended the ride before the rider returned approximately 15 minutes later. | `rideInactivityPrompted` at `2026-08-06T18:43:44Z`; automatic `rideEnded` exactly two minutes later. | Major | Awaiting triage. Diagnostics prove prompt logic and automatic end, but do not prove whether iOS delivered or displayed a notification; non-observation is not recorded as non-delivery. |
| RH-UAT-2026-08-06-10 | Place-awareness experience; `2026-08-06-RB-01` | Rider product observation after the field session. | RideHorizon used alongside another foreground app, with spoken announcements optionally enabled or disabled. | A rider can recover the latest changed place name in writing without returning to RideHorizon or relying on memory of a completed speech announcement. | No cross-app written place-change indication was available. The rider requested a notification or similarly appropriate passive indication containing the changed sub-locality or locality, independent of whether speech is enabled. | Observe a meaningful place change while another app is foregrounded, or after speech has completed, then attempt to recover the announced place name without reopening RideHorizon. | Minor | Awaiting triage. Feature request only; presentation, notification frequency and moving-rider safety require product design. |

### Run conclusion

| UAT test | Final result |
|---|---|
| RUAT3-01 | Fail |
| RUAT3-02 | Fail, with positive music/navigation and Bluetooth coexistence evidence |
| RUAT3-03 | Not observed |
| RUAT3-04 | Partial |

Recommendation: **revise**. Retain the useful foreground coexistence and place-awareness behaviour, but revise background/locked playback, speech continuity and provider fallback before widening the ride-test scope.

## Release evidence gate

External TestFlight invitations remain blocked until:

- all mandatory pre-road tests pass on the exact uploaded build;
- all mandatory field, inactivity and end-of-ride tests pass on the same build or an approved replacement;
- no unresolved failure can cause distracting audio, a sudden volume increase, failure to honour an observable iOS audio interruption, unbounded background location, a crash or a credential prompt;
- `docs/operations/testflight/TESTFLIGHT_PRIVATE_BETA_PACK.md` administrative gates are complete;
- Rob records the explicit milestone decision: **continue**, **revise**, **refactor**, **research**, **prototype**, **reduce scope**, **pause** or **stop**.

This evidence format follows [SOP: Adaptive Agentic Software Delivery v1.6](https://app.notion.com/p/3aea4c502b1781a888b1f8e851697813), reviewed on 2026-08-17. Recheck that source if its version or current date changes materially.

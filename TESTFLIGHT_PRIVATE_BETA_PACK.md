# RideHorizon Private TestFlight Beta Pack

Date: 2026-07-31

Status: Build `0.12.3 (20260731.1608)` uploaded successfully on 2026-07-31 and remains the latest App Store Connect build. Candidate `0.12.3 (20260731.2020)` adds the final public privacy-policy link, private-beta hardening, clean-install UI coverage, simulator-discovered onboarding fixes and the reviewed rider-network retry/timeout strategy. Its iOS unit, proxy and Cloudflare suites pass, the earlier UI suite remains green, and a generic iPhone build passes. Fly production version 38 keeps one machine warm and passed fresh live health, automatic-session, fact and ElevenLabs audio checks. The validated `20260731.1942` archive is superseded by the reliability changes. The local Xcode Apple ID session must be refreshed before `20260731.2020` is archived and uploaded, and the exact build still needs installation on the currently unavailable target iPhone. Builds `20260731.1519`, `20260731.1645`, `20260731.1857`, `20260731.1930` and `20260731.1942` must not be assigned to testers.

## Release Decisions — 2026-07-31

- The first beta supports iPhone only.
- No tester enters an invite code, proxy token, or API credential.
- Automatic restricted proxy sessions are permitted for this first private beta while full App Attest verification remains under development.
- Standard HTTPS/platform cryptography is expected to qualify for the export-compliance exemption; the account holder confirms the App Store Connect answer.
- The release candidate must use a working public privacy-policy URL and a working monitored feedback address.

## External TestFlight Submission Acceptance Criteria — 2026-07-31

- App Store Connect uses `https://ridehorizon.digitalmercenaries.ai/app-privacy-policy` as the privacy-policy URL.
- The same URL is reachable from the privacy notice inside the shipped iOS build.
- The privacy-policy page is public over HTTPS, requires no sign-in, contains no placeholder text, and identifies Digital Mercenaries Limited and a monitored privacy contact.
- The App Store Connect Beta App Description, What to Test text, and Beta App Review notes match the actual build and are copied from `APP_STORE_CONNECT_TEST_INFORMATION.md`.
- Reviewers can exercise the core experience without an account, invite code, proxy token, API key, motorcycle ride, or Bluetooth hardware.
- Test Mode can trigger representative location changes, AI facts, Premium Voice, and Apple Voice fallback while stationary.
- The production proxy remains available throughout review and automatically provisions restricted app sessions.
- Optional AI and Premium Voice disclosures are presented before provider sharing; names-only announcements and Apple Voice remain available when sharing is declined.
- A clean launch does not contact the RideHorizon proxy until the rider enables optional AI features and a proxy-backed feature first needs access.
- Onboarding tells the rider to complete setup while stopped, avoid interacting with the phone while moving, and stop using RideHorizon if it becomes distracting.
- An earlier build launched on the target physical iPhone, and the production `/v1/speech` route returns valid MP3 audio. The exact candidate still needs its physical-device smoke test.

## Purpose

Run a small, named UK private beta to learn whether RideHorizon works safely and usefully on real motorcycle rides with normal navigation and helmet audio.

Start with 3 to 5 riders. Do not publish a public TestFlight link for this cohort.

## Tester Eligibility

Invite riders who:

- Have an iPhone compatible with the uploaded build.
- Ride in the UK and can complete at least one ordinary ride during the beta window.
- Can use Bluetooth helmet audio or headphones, if possible.
- Understand that this is a beta, not navigation, safety, or emergency software.

Aim for a mix of touring riders, a daily rider, a group/club rider, and a privacy or safety sceptic.

## Tester Invitation

> Hi [name],
>
> I’m inviting you to a small TestFlight beta for RideHorizon, an iPhone audio companion for motorcyclists. It gives short, optional place updates as you ride and is designed to run alongside your usual navigation app.
>
> This is an early beta. Please only set it up while stopped, keep your normal navigation and riding judgement in charge, and stop using it if it distracts you or behaves unexpectedly.
>
> I’m looking for one real-ride report covering location, background behaviour, helmet audio, usefulness, and any safety concerns. Your TestFlight link and simple feedback questions will follow once the build is ready.

## First-Ride Instructions

Send these with the TestFlight invitation:

1. Install TestFlight from the App Store, accept the RideHorizon invitation, and install the beta.
2. Before riding, open RideHorizon and complete onboarding while stationary.
3. Grant location permission when asked. Enable the option that allows location use while the app is not on screen if iOS offers it.
4. Connect your usual Bluetooth helmet headset. Check the device volume and listen to one test announcement while stopped.
5. Start normal navigation in your preferred navigation app. RideHorizon is a companion and does not provide directions.
6. Use the default announcement settings for the first ride. Do not change settings while moving.
7. If speech is distracting, incorrect, too frequent, or the app behaves unexpectedly, switch to Quiet mode or stop using the app until safely parked.
8. After the ride, send the feedback below. Include the approximate ride duration and whether the app was in the foreground, background, or both.

## Feedback Form

Use these questions in a short form or email reply:

1. Date of the ride (YYYY-MM-DD):
2. Approximate ride duration: under 30 minutes / 30–90 minutes / more than 90 minutes.
3. Did you use Bluetooth helmet audio? yes / no. If yes, which headset?
4. Did RideHorizon continue working while your navigation app was open or the screen was off? yes / partly / no / not sure.
5. Did you hear announcements reliably? always / mostly / rarely / never.
6. Were announcements too frequent, too long, distracting, or mistimed? Describe any moment that felt unsafe or irritating.
7. Were the place announcements useful? very useful / somewhat useful / not useful. Why?
8. Did you use Quiet mode or stop using the app during the ride? Why?
9. Did the app affect battery, navigation, headset audio, or phone heat noticeably? Describe what happened.
10. Did the app crash, lose location, show an error, or produce incorrect place information? Include a screenshot only if safely captured after stopping.
11. Would you choose to use RideHorizon again on your next ride? yes / no / maybe. Why?
12. May we contact you for a 15-minute follow-up? yes / no.

## Release Gate

Do not invite external testers until all items are true:

- A signed, non-internal-only build has uploaded and processed in App Store Connect.
- The current build has passed a physical iPhone smoke test using location, background behaviour, and Bluetooth audio.
- Automatic restricted proxy sessions work in the TestFlight environment; the app also retains names-only and Apple-voice behaviour when proxy access is unavailable.
- No upstream API key, shared bearer credential, or manual tester credential entry is present in the build or tester instructions.
- Privacy and support contact details are ready to send to testers.
- The App Store Connect Test Information page is saved with contact details and review notes that match the shipped build.
- The first external build has been submitted for, and approved by, TestFlight App Review.

## Operator Checklist

1. Add the processed build to `RideHorizon Internal` and test it before external submission.
2. Create the external group only when it is available in App Store Connect.
3. Submit the first external build for TestFlight App Review.
4. Add named testers by email after approval. Keep automatic notification off until the invitation and feedback form are ready.
5. Send the invitation and first-ride instructions.
6. Review each report within two working days. Pause invitations if a safety, background-location, Bluetooth-audio, crash, or proxy-access issue recurs.

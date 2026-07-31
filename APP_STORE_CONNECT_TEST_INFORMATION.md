# RideHorizon App Store Connect Test Information

Date: 2026-07-31

Use this copy for the first private external TestFlight submission. Keep the production proxy online while the build is in review.

## Beta App Description

RideHorizon is an iPhone audio place-awareness companion for motorcyclists. It uses location changes to announce nearby towns, counties and regions through the device speaker or a Bluetooth helmet headset. Testers can choose names-only announcements, optional AI-generated short or long place facts, Apple Voice or Premium Voice. RideHorizon runs alongside the tester's normal navigation app; it does not provide routes, safety instructions or emergency guidance. This private beta is focused on real-ride reliability, background location, Bluetooth audio, announcement usefulness and distraction risk.

## What to Test

Please complete setup while stationary. Test onboarding and the location and optional AI-sharing choices. Use Test Mode in Settings > Advanced > Developer to step through the Gloucestershire sample route without travelling. Check Names Only, Short Facts and Long Facts; Apple Voice and Premium Voice; Quiet Mode; background operation with the screen locked or another navigation app open; Bluetooth helmet audio if available; interruption handling for calls, navigation and music; and Apple Voice fallback if Premium Voice is unavailable. Report missing, late or repeated announcements, incorrect places or facts, crashes, excessive battery use, audio conflicts, and anything distracting. RideHorizon is not navigation, safety or emergency software.

## Beta App Review Notes

No account, invite code, proxy token or API credential is required. Network access is provisioned automatically at first launch.

To test without travelling: launch the app, complete onboarding while stationary, allow location, enable optional AI sharing if you wish to test AI facts or Premium Voice, then open Settings > Advanced > Developer and enable Test Mode. Advance through the Gloucestershire sample route to trigger location changes and announcements. Bluetooth hardware is optional; the iPhone speaker is sufficient.

Apple Voice remains available if external AI or speech services are declined or unavailable. RideHorizon is an audio place-awareness companion and does not provide navigation, safety, emergency or vehicle-control functions. The production proxy and provider services will remain online during review.

Privacy policy: https://ridehorizon.digitalmercenaries.ai/app-privacy-policy

## Remaining App Store Connect Fields

- Feedback Email: use a real monitored inbox that the beta team checks.
- Contact Information: use the existing first name, last name, phone number and monitored email for the person Apple can contact during review.
- Sign-in Required: No.
- Export Compliance: answer using the app's standard HTTPS/platform cryptography exemption information and the account holder's final confirmation.

## What Apple Is Likely to Exercise

- Installation, first launch and onboarding without a crash or manual credential.
- Location permission wording and the app's behaviour when permission is allowed or declined.
- Optional AI-sharing consent before OpenAI facts or ElevenLabs Premium Voice are used.
- Test Mode as a stationary path through the main functionality.
- Names-only announcements, AI fact generation, Premium Voice and Apple Voice fallback.
- The in-app privacy-policy link and the App Store Connect privacy-policy URL.
- A live production backend and working links, with no placeholder pages.
- The accuracy of the review notes, privacy declarations and safety positioning.

## TestFlight Review Versus Full App Review

External TestFlight builds are still subject to Apple's App Review Guidelines. The first build submitted to an external testing group receives TestFlight App Review; later builds may not require another review unless Apple selects them or the changes are significant. Internal TestFlight testing does not require TestFlight App Review.

TestFlight review is normally narrower than a full public App Store review because the product is explicitly a beta and the public product-page release is not being approved. It is not a relaxed policy regime: Apple can reject a beta for crashes, broken or placeholder URLs, misleading review information, privacy or consent failures, an unavailable backend, unsafe behaviour, prohibited content, or use of TestFlight for an app that is not intended for eventual public distribution.

A later public App Store submission also requires the final store listing and screenshots, age rating, availability and pricing, support and marketing details, legal and regional declarations, final App Privacy answers, and a release-quality build suitable for public distribution.

Official references:

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/

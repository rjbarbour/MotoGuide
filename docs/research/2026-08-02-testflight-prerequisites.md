# TestFlight prerequisites for RideHorizon

Date checked: 2026-08-02
Scope: iPhone-only build, private external beta, official Apple sources only.

## Direct answer

For external TestFlight testing, RideHorizon needs a valid App Store distribution build, completed beta test information, an export-compliance determination and approval from TestFlight App Review. A full public App Store product page is not required first, but external TestFlight is not exempt from the App Review Guidelines.

The shortest path is to upload one release archive using **TestFlight & App Store**, make it available to a small internal group, then submit that same build to a private external group using email invitations.

## Hard prerequisites and likely blockers

- The Apple Developer Program membership must be active. Free apps are covered by the Apple Developer Program License Agreement; the Paid Apps Agreement is required only to sell an app or offer In-App Purchases. Only the Account Holder can accept agreements. Check **Business → Agreements** for anything awaiting acceptance. [Apple: sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)
- The upload must be made by an Account Holder, Admin, App Manager or Developer. Creating and managing the external group requires an Account Holder, Admin or App Manager. [Apple: upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/) [Apple: invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- As of 2026-04-28, an iOS upload must be built with the iOS 26 SDK or later. In practice, use Xcode 26 or later. [Apple: current submission requirements](https://developer.apple.com/app-store/submitting/)
- The App Store Connect app record must already exist and its Bundle ID must exactly match the Xcode target. The Bundle ID cannot be changed after a build is uploaded. Each upload must have a unique build string. [Apple: app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) [Apple: preparing an app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)
- Archive the release build, validate it, fix validation errors, and upload it using **TestFlight & App Store**. Do **not** use **TestFlight Internal Only**, because such a build can never be submitted for external testing or public distribution. [Apple: distributing beta builds and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- The distribution provisioning profile must include the application identifier. A missing identifier makes the build unavailable for TestFlight. [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) [Apple: build statuses](https://developer.apple.com/help/app-store-connect/reference/app-build-statuses/)
- The build must contain its app icon; Apple displays the icon in TestFlight from the uploaded build. [Apple: add an app icon](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon)
- After upload, Apple must finish processing the build. `Invalid Binary`, `Not Available for Testing` and `Missing Compliance` require action; `Ready to Submit` means it can be sent to TestFlight App Review. [Apple: build statuses](https://developer.apple.com/help/app-store-connect/reference/app-build-statuses/)
- Encryption use must be declared for the beta build. Answer the TestFlight export-compliance questions or set the correct encryption keys in `Info.plist`; upload documentation if Apple determines it is required. Otherwise the build remains `Missing Compliance`. [Apple: export compliance for beta builds](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds) [Apple: export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- Any included privacy manifest must be valid. Listed third-party SDKs require their own privacy manifest and, when included as binary dependencies, a signature. App Store Connect rejects invalid manifests. [Apple: privacy manifests](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk) [Apple: third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)

## TestFlight information to complete

In **Apps → RideHorizon → TestFlight → Test Information**, provide:

- Beta App Description — required.
- Feedback Email — used by TestFlight and as the invitation reply-to address.
- TestFlight App Review contact name, email and telephone number.
- Sign-in information for a non-expiring demo account if any feature requires login; otherwise state that no login is required.
- Review notes describing any setup, special configuration or test path needed to reach the main functionality.

For each build added to a group, add specific **What to Test** text. [Apple: provide test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information) [Apple: TestFlight test information](https://developer.apple.com/help/glossary/testflight-test-information/) [Apple: invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)

For RideHorizon, the review notes should give exact steps to use Test Mode so the reviewer can exercise location changes, facts and speech without riding. State that no proxy token, invite code or login is required; the service is available automatically; the app can be assessed through the iPhone speaker without a helmet headset. Keep the Fly proxy and ElevenLabs path running throughout review. Apple explicitly asks developers to provide full access, keep backends on and explain special configuration or hardware. [Apple: App Review Guidelines, sections 2.1 and 2.2](https://developer.apple.com/app-store/review/guidelines/)

## Privacy and public URLs

- A working Privacy Policy URL is required for an iOS app. The supplied URL must remain publicly accessible and must match actual app and server behaviour. [Apple: manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- Complete and publish the App Privacy questionnaire, including data handled by the app, the RideHorizon proxy and third-party partners. Apple describes these responses as an App Store product-page requirement, but TestFlight submissions must still have accurate privacy metadata and comply with the App Review Guidelines. Complete it now rather than making it a later release blocker. [Apple: manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/) [Apple: App Review Guidelines, section 2.3](https://developer.apple.com/app-store/review/guidelines/)
- A User Privacy Choices URL is optional. [Apple: app privacy reference](https://developer.apple.com/help/app-store-connect/reference/app-privacy/)
- Verify every link in the app, especially privacy and support links. Broken links and placeholder pages are common completeness failures. [Apple: avoiding common review issues](https://developer.apple.com/app-store/review/)

## Internal versus external testing

- Internal testers must be App Store Connect users with appropriate access. Up to 100 may test without TestFlight App Review. [Apple: add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)
- External testers need not be App Store Connect users. Up to 10,000 may be invited by email or public link. For a genuinely private beta, use email invitations rather than a shareable public link. Tester devices do not need to be registered in Certificates, Identifiers & Profiles. [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) [Apple: invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- Apple currently requires an internal group to exist before an external group can be created. [Apple: invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- The first externally distributed build receives a full TestFlight App Review. Later builds of the same version might not receive a full review. Only one build of a version can be in review at once, and no more than six builds may be submitted to TestFlight App Review in 24 hours. [Apple: invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- Each TestFlight build expires after 90 days. [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

## What Apple reviews

External TestFlight is lighter administratively than a full App Store release, not a lower policy standard. Apple says a TestFlight beta must be intended for eventual public distribution and comply with the App Review Guidelines. TestFlight cannot be used to compensate testers. [Apple: App Review Guidelines, section 2.2](https://developer.apple.com/app-store/review/guidelines/)

The practical review risks for this build are:

- crashes, hangs or obvious functional defects;
- placeholder copy, images or unfinished screens;
- inaccurate metadata or undocumented features;
- a privacy or support link that does not work;
- an unavailable proxy, fact or speech service;
- the reviewer being unable to trigger the core location-driven experience;
- missing permission explanations or a feature failing after location permission is declined;
- third-party content without the necessary rights;
- privacy declarations that omit server-side or third-party handling.

Apple says over 40% of unresolved review issues concern App Completeness, including crashes, placeholders and incomplete review information. [Apple: avoiding common review issues](https://developer.apple.com/app-store/review/)

## Not required merely to start external TestFlight

The complete public App Store listing — public description, keywords, public screenshots, Support URL, copyright, pricing/availability and release settings — is needed for the eventual App Store submission, but the beta has its own TestFlight description, feedback address and review information. Approved App Store screenshots and category may optionally appear in the TestFlight invitation. [Apple: provide test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information) [Apple: platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

Tax and banking setup are not needed merely to test or distribute a free app with no In-App Purchases. They become relevant if RideHorizon is sold or adds paid digital features, when the Paid Apps Agreement also becomes necessary. [Apple: sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)

## Submission blocker checklist

- [ ] Developer membership active; no pending licence agreement.
- [ ] App Store Connect Bundle ID exactly matches the release target.
- [ ] iPhone release archive built with Xcode 26/iOS 26 SDK or later.
- [ ] Archive validated and uploaded as **TestFlight & App Store**, not Internal Only.
- [ ] Build processing completes without invalid-binary, provisioning, privacy-manifest or other errors.
- [ ] Export compliance resolved; build no longer says `Missing Compliance`.
- [ ] Privacy Policy URL loads publicly and matches actual data handling.
- [ ] App Privacy answers completed and published accurately.
- [ ] Beta App Description and Feedback Email completed.
- [ ] Review contact details, no-login statement and RideHorizon Test Mode instructions completed.
- [ ] Build-specific **What to Test** text completed.
- [ ] Fly proxy, session issuance, fact generation and ElevenLabs speech verified live and kept available.
- [ ] Release build tested on a physical iPhone for permissions, background location, Bluetooth audio, interruption handling and weak/mobile data.
- [ ] No token/invite prompt, placeholder content or broken in-app link remains.
- [ ] Internal group created, then private external email group created.
- [ ] First external build submitted to TestFlight App Review and approved before invitations are sent.

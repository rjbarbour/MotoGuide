# App Store submission requirements and likely RideHorizon gotchas

**Research date:** 2026-07-18
**Scope:** New public iOS app submission through App Store Connect and App Review. TestFlight differences are included where relevant. Sources are official Apple documentation only. This is operational guidance, not legal advice.

## Bottom line

RideHorizon should not be submitted to the public App Store merely because a build passes TestFlight. The public submission needs a release build that is stable on a physical iPhone, complete App Store metadata, a working support site and privacy policy, accurate privacy declarations, correct privacy manifests and signing, live backend services, and a reviewer path that exercises the full app without a real motorcycle ride.

The highest-risk rejection areas for this product are:

1. **Privacy and third-party AI consent.** Apple requires clear disclosure and explicit permission before personal data is shared with third parties, expressly including third-party AI. Location-derived place information and rider-entered instructions can be personal data. The consent must happen before the first such request; a privacy policy alone is insufficient. [App Review Guidelines 5.1.1 and 5.1.2](https://developer.apple.com/app-store/review/guidelines/#privacy)
2. **Background location justification.** Background location is legitimate only when directly relevant, clearly explained, consented to, and configured for its intended purpose. Apple prefers the least powerful authorization that works. [App Review Guidelines 5.1.5](https://developer.apple.com/app-store/review/guidelines/#location-services), [Apple: requesting location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services), [Apple: handling background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)
3. **Physical-safety presentation.** Apple may reject apps that encourage device use in a way that risks physical harm. RideHorizon should make setup-before-riding, short audio output, hands-free operation, and “not navigation, safety, or emergency guidance” clear in the app, metadata, and review notes. [App Review Guidelines 1.4](https://developer.apple.com/app-store/review/guidelines/#physical-harm)
4. **Reviewer access and backend readiness.** Apple expects full access, an active non-expiring demo account or fully featured demo mode where applicable, any special instructions, and all backend services online during review. [Apple: Before You Submit](https://developer.apple.com/app-store/review/guidelines/#before-you-submit), [App Store Connect: platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
5. **Privacy manifest / required-reason API failure.** App Store Connect rejects apps that use required-reason APIs without valid approved reasons. Direct `UserDefaults` use normally requires a bundled `PrivacyInfo.xcprivacy` entry for `NSPrivacyAccessedAPICategoryUserDefaults`; Apple documents `CA92.1` for app-only defaults. [Apple: required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [Apple TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
6. **Submitting an obviously beta product.** Public App Review expects a final, complete version. Placeholder text, broken URLs, temporary content, crashes, obvious technical defects, and “beta” positioning are rejection risks. TestFlight is the correct place for unfinished software. [App Review Guidelines 2.1 and 2.2](https://developer.apple.com/app-store/review/guidelines/#performance)

## Submission gate

### 1. Account, agreements, price, and availability

- The Apple Developer Program License Agreement covers distribution of free apps. A Paid Apps Agreement is required only to sell a paid app or offer In-App Purchases. Banking and tax information are needed to receive payments under the paid agreement, not simply to release a free app. [Apple: sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/), [Apple: provide tax information](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information)
- The Account Holder must accept updated program agreements. An unaccepted or pending agreement can block App Store Connect functions. [Apple: program roles and updated agreements](https://developer.apple.com/help/account/access/roles), [Apple: agreement statuses](https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status)
- Set the app price to **Free** if that is the launch model, select an accurate tax category, select public distribution, choose countries or regions, and choose manual or automatic release. Availability is required before review. [Apple: publishing overview](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store), [Apple: manage availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store), [Apple: release options](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/)
- Distribution method is a consequential choice. After approval, changing between public and private distribution requires a new app record; a public app can later request unlisted distribution. [Apple: set distribution methods](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/set-distribution-methods)

**RideHorizon implication:** a free public launch does not need the Paid Apps Agreement, banking, or tax forms unless another requirement applies. The important exception is EU trader status: Apple says all traders must provide payment account details for DSA verification even if they have not already done so. [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)

### 2. EU DSA and regional compliance

- A trader-status declaration is required even if the app will not be distributed in the EU. If distributed in the EU as a trader, Apple verifies and displays the trader's address, phone number, and email on the product page. Organizations use the D-U-N-S-linked address and supply phone/email; all traders may be asked for payment-account details and supporting documents. [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
- Apple says an organization or anyone developing in connection with a business activity is likely to be a trader, but the developer must make the legal assessment. [Apple: DSA trader self-assessment](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
- Choose regions intentionally. “All countries or regions” also opts the app into future storefronts. Some regions have additional legal prerequisites; for example, some China-mainland apps require a valid ICP filing. [Apple: manage availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store), [Apple: app information and regional requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)

**RideHorizon implication:** if Digital Mercenaries Ltd is the submitting organization and the app is a business product, “trader” is the likely DSA answer. Treat that as a legal/business conclusion to confirm, not an App Store optimization. Complete verification early because documents and payment-account checks can take time. For an initial UK-only validation launch, do not select worldwide availability by reflex.

### 3. Build tools, versioning, bundle identity, signing, and icons

- Since 2026-04-28, iOS and iPadOS uploads must be built with **Xcode 26 or later** using the iOS 26 / iPadOS 26 SDK or later. A TestFlight beta built with a beta Xcode can be accepted for testing without necessarily being valid for public App Store distribution, so use a supported release Xcode for the public archive. [Apple: Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/), [Apple: SDK minimum requirements](https://developer.apple.com/news/?id=ueeok6yw)
- The bundle ID in App Store Connect must match the Xcode target. The combination of bundle ID, version number, and build string uniquely identifies a build, and a build string must distinguish each upload. The bundle ID cannot be changed after a build is uploaded. [Apple: app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [Apple: upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- Use the correct team, an App Store distribution identity/profile, and entitlements that match the App ID and target capabilities. Changing enabled App ID capabilities invalidates existing provisioning profiles. Automatic signing is usually the lowest-risk route. [Apple: distributing releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases), [Apple: enable app capabilities](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)
- Validate the final archive in Xcode before upload. Validation is limited and does not replace App Review, but catches packaging and signing issues earlier. [Apple: distributing releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- The app bundle must include App Store icon imagery. iOS/iPadOS can generate variants from a 1024×1024 asset; ensure the Release target points at the intended app icon set and contains no development icon. [Apple: configuring the app icon](https://developer.apple.com/documentation/xcode/configuring-your-app-icon/)

**Common gotchas:** reusing a build number after a failed upload, changing the bundle ID between the app record and archive, archiving a Debug configuration, leaving development endpoints or diagnostics enabled, missing Release entitlements, and accidentally shipping both debug and production app icons.

### 4. Privacy manifest, SDK manifests, and required-reason APIs

- A privacy manifest is a target resource named `PrivacyInfo.xcprivacy`. It describes collected-data categories, tracking domains, and required-reason APIs. App Store Connect rejects invalid manifests and, since 2024-05-01, rejects uploads that use a covered API without an approved reason. [Apple: privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [Apple: add a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk), [Apple: required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- Each executable or dynamic library that uses a required-reason API must carry the corresponding declaration in its own bundle; an app manifest cannot substitute for a framework's missing declaration. [Apple: required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- Apple maintains a list of commonly used third-party SDKs that require privacy manifests and, for binary dependencies, signatures. The developer is responsible for every included SDK and should use current compliant SDK versions. [Apple: third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- Xcode can produce a combined privacy report from manifests. Compare that report with the actual app/proxy data flows and the App Store Connect privacy answers; these three descriptions need to agree. [Apple: privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [Apple: manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)

**RideHorizon implication:** the earlier audit identified direct `UserDefaults` use. Apple documents `CA92.1` for defaults accessible only to the app itself. That entry should be in a valid manifest included in the Release target. Any third-party packages in the final binary also need a manifest/signature audit.

### 5. Privacy policy, App Privacy answers, consent, and deletion

- Every iOS app needs a public Privacy Policy URL in App Store Connect and an easily accessible privacy-policy link inside the app. The policy must identify collection and uses, third-party protections, retention/deletion, consent withdrawal, and how users request deletion. [App Review Guidelines 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage), [Apple: manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- App Store Connect privacy answers must cover the app and integrated third-party partners. They must be accurate and kept current. On-device-only processing is not “collection” for the label, while off-device data retained by the developer or a provider normally is. [Apple: App privacy details](https://developer.apple.com/app-store/app-privacy-details/), [Apple: manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- Apps that collect user or usage data must obtain consent, provide a clear withdrawal route, use complete purpose strings, minimize data, and respect refusals. If the app creates accounts, it must offer account deletion within the app. [App Review Guidelines 5.1.1(ii)–(v)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- Before personal data is shared with a third party, Apple requires disclosure of how and where it will be used and explicit permission. The rule expressly names third-party AI. [App Review Guidelines 5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)
- Tracking under Apple's definition requires App Tracking Transparency; ordinary first-party security/authentication does not automatically amount to tracking. [Apple: user privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/)

**RideHorizon implication:** do not submit until the in-app AI-sharing consent and withdrawal path exist, the public policy is live and matches the implementation, and the final privacy-label answers have been reconciled with OpenAI, ElevenLabs, hosting, logging, App Attest, and diagnostic retention. If the user declines AI sharing, the app should still provide a coherent non-AI experience such as names-only / Apple voice.

### 6. Location and background audio

- Location Services must be directly relevant, and the app must notify and obtain consent before collecting, transmitting, or using location data. Location must not be represented as emergency guidance or autonomous vehicle control. [App Review Guidelines 5.1.5](https://developer.apple.com/app-store/review/guidelines/#location-services)
- Apple prefers **When In Use** authorization whenever possible. When an iOS app has active background-location support and the location indicator is enabled, When In Use authorization can continue delivering updates in the background; Always authorization is for cases that need events or relaunch when the app is not running. [Apple: choosing location authorization](https://developer.apple.com/documentation/corelocation/choosing-the-location-services-authorization-to-request), [Apple: requesting location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
- Background location requires the Location updates background capability / `UIBackgroundModes` location entry. The app must communicate that background updates will occur. If Always access is actually requested, `NSLocationAlwaysAndWhenInUseUsageDescription` is required; protected-resource purpose strings must be specific and complete. [Apple: handling background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background), [Apple: `NSLocationAlwaysAndWhenInUseUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationalwaysandwheninuseusagedescription), [Apple: protected resources](https://developer.apple.com/documentation/bundleresources/protected-resources)
- Background services may only be used for their intended purposes. Audio playback and location are valid modes, but declaring a mode that is not genuinely used for that purpose can trigger rejection. [App Review Guidelines 2.5.4](https://developer.apple.com/app-store/review/guidelines/#software-requirements), [Apple: `UIBackgroundModes`](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes)
- Background audio requires the Audio, AirPlay, and Picture in Picture background capability and a correctly configured audio session. The system expects apps to coexist with calls and higher-priority audio. [Apple: configuring media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)

**RideHorizon gotchas:** requesting Always location during onboarding before demonstrating value; vague purpose text such as “needed for a better experience”; tracking after the rider stops a session; keeping the audio session active continuously rather than only to deliver the app's audio; failing to handle calls, navigation prompts, Siri, Bluetooth disconnection, lock-screen operation, and permission revocation. These are product/testing risks as well as review risks.

### 7. Metadata, screenshots, category, and age rating

Complete and accurately localize at least:

- app name, subtitle, primary language, primary category, age rating, content-rights answer, privacy policy URL, and DSA status;
- version number, copyright, description, keywords, Support URL, screenshots, App Review contact information, release option, price, and availability; and
- the selected processed build. Apple will not submit the version until required metadata and a build are present. [Apple: required properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/), [Apple: platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), [Apple: submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)

Metadata rules and likely gotchas:

- Description is limited to 4,000 characters; keywords to 100 bytes; app name and subtitle to 30 characters. Keywords must not contain other app/company names. [Apple: platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), [Apple: app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [App Review Guidelines 2.3.7](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)
- Screenshots must show the app in use, not only a splash/login screen. They must reflect the actual submitted build and must use fictional rather than real personal data. [App Review Guidelines 2.3.3 and 2.3.9](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)
- Provide one to ten screenshots per required device family. For iPhone, Apple accepts the current 6.9-inch sizes and scales where documented. If the target runs on iPad, 13-inch iPad screenshots are required. Images cannot contain alpha channels or transparency. [Apple: screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [Apple: upload screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- Category must match the core experience. Apple defines Travel as helping with an aspect of travel and Navigation as helping a user travel to a physical location. For RideHorizon's current “place-awareness companion, not navigation” positioning, **Travel primary** and possibly **Navigation secondary** are defensible; the final choice must match the shipped experience and metadata. [Apple: choosing a category](https://developer.apple.com/app-store/categories/)
- Age rating is mandatory and must be based on honest questionnaire responses. Apple introduced a revised age-rating system and the questionnaire now contains social-media questions; those social-media responses become required for submissions in 2026-09, but can be answered now. [Apple: set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating), [Apple: social-media age-rating questions](https://developer.apple.com/news/?id=tlur8uvi)
- Do not mark the app Made for Kids unless that is a deliberate, permanent product commitment; Apple says the selection cannot be changed after approval and future versions must obey Kids Category rules. [Apple: app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)

### 8. Support URL, privacy URL, and public-facing completeness

- The Support URL must lead to a functioning page with an easy way to contact the developer. Apple requires accurate, current developer contact information. [App Review Guidelines 1.5](https://developer.apple.com/app-store/review/guidelines/#developer-information)
- All URLs submitted for review must work and must not be placeholders or empty sites. [App Review Guidelines 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness)
- Avoid using a private Notion page, local landing page, “coming soon” page, or mailto-only link as the support site. The page should identify RideHorizon, provide support contact instructions, link the privacy policy, and explain any known requirements such as compatible iOS versions and Bluetooth being optional.

### 9. Content rights and AI-generated facts

- The content-rights declaration covers third-party content the app contains, displays, or accesses. The developer must have permission under the service's terms and be able to provide authorization on request. [Apple: app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [App Review Guidelines 5.2.1–5.2.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)
- Rights also apply to app icons, screenshots, previews, maps, photos, fonts, audio, and marketing overlays. Screenshots should not expose real rider information. [App Review Guidelines 2.3.9](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)
- Apple prohibits false information and misleading claims. AI-generated place facts should be bounded, screened, and presented without claims of guaranteed accuracy. The app and metadata must not imply Apple endorsement. [App Review Guidelines 1.1.6](https://developer.apple.com/app-store/review/guidelines/#objectionable-content), [App Review Guidelines 5.2.4](https://developer.apple.com/app-store/review/guidelines/#apple-endorsements)

**RideHorizon implication:** document the rights/terms basis for each content or service source used in facts, geocoding, maps, and speech. If the app uses only Apple MapKit output and provider-generated text/audio, verify the relevant service terms and required attributions. Do not put third-party trademarks in the app name, keywords, or screenshots merely for discoverability.

### 10. Review access, demo mode, backend, and review notes

- App Review needs full access. If account-based functionality exists, provide a non-expiring active demo account or a fully featured demo mode, plus any required settings, hardware, sample code, or resources. The backend must be live and reachable during review. [Apple: Before You Submit](https://developer.apple.com/app-store/review/guidelines/#before-you-submit)
- App Review notes should explain non-obvious functionality and exact testing steps. App Store Connect accepts contact information, notes, and sign-in details; credentials are required when login is required. [App Store Connect: platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- The public build must work on IPv6-only networks. [App Review Guidelines 2.5.5](https://developer.apple.com/app-store/review/guidelines/#software-requirements)

**Recommended RideHorizon review path:**

1. Launch the app and complete onboarding.
2. Explain exactly when the location and third-party-AI consent prompts appear.
3. Provide an in-app test route that demonstrates boundary detection, names-only announcements, facts, Apple speech, and—if included in the public version—the third-party speech path without requiring travel.
4. Keep the production proxy and AI/speech providers online, with reviewer traffic accepted and no short-lived invite code.
5. Explain that Bluetooth is optional and device speaker output is enough to review.
6. State that RideHorizon is an audio place-awareness companion, not a navigation, safety, emergency, or vehicle-control product.
7. Describe background location/audio, how a rider starts and stops a ride session, how the app avoids continuous distraction, and what the user sees when AI consent or location permission is declined.

Do not leave developer-only reset controls, proxy diagnostics, internal endpoints, sample secrets, or misleading test labels visible in the public build unless they are intentional, safe user features and documented for review.

### 11. Stability, completeness, safety, and minimum functionality

- Apple says to test for crashes and bugs, make metadata accurate, and submit a final version. Incomplete bundles, crashes, obvious technical problems, placeholder text, empty URLs, and temporary content can be rejected. [Apple: Before You Submit](https://developer.apple.com/app-store/review/guidelines/#before-you-submit), [App Review Guidelines 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness)
- Apps need adequate native utility and a useful, app-like experience. [App Review Guidelines 4.2](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality)
- Apps may only use public APIs, must run on the currently shipping OS, and must use APIs and background services for their intended purposes. [App Review Guidelines 2.5](https://developer.apple.com/app-store/review/guidelines/#software-requirements)
- Metadata, privacy information, screenshots, and the actual build must tell the same story; hidden or undocumented features and generic review notes can be rejected. [App Review Guidelines 2.3](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)

**Release evidence to prepare before submission:**

- clean install and first-run test on the oldest supported iOS version and the current shipping iOS version;
- real iPhone ride tests with screen locked, app backgrounded, another navigation app active, Bluetooth connected/disconnected, calls/Siri/audio interruptions, poor connectivity, proxy failure, AI refusal, approximate location, precise location disabled, and location permission revoked;
- a no-network/failing-backend behavior that is understandable and does not strand the reviewer;
- confirmation that stopping a ride ends the relevant location/background activity and that relaunch/restoration behaves as described;
- crash-free internal/TestFlight soak evidence and a final Release archive validation;
- a screenshot/metadata pass against the exact final build.

## Accessibility Nutrition Labels

Accessibility Nutrition Labels are **voluntary as of 2026-07-18**. Apple says they will become mandatory over time, but has not yet made them a submission blocker. If no answers are provided, the product page shows that support has not yet been indicated. Any claimed feature must let users complete all common tasks with that feature. [Apple: Accessibility Nutrition Labels overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)

For RideHorizon, accessibility evaluation is still worth doing before launch because first-run permission, starting/stopping a ride, settings, and privacy controls are common tasks. Do not claim VoiceOver, Voice Control, Larger Text, contrast, or other support until those tasks meet Apple's published criteria. The accessibility URL is optional. [Apple: manage Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels)

## Export compliance

- Any app that uses, accesses, contains, implements, or incorporates encryption must answer App Store Connect's export-compliance questions. This includes use of cryptography supplied by the operating system, but the answers determine whether documentation is needed. [Apple: export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- A build with **Missing Compliance** cannot be selected for review until the questions are answered or approved documentation is attached. [Apple: choose a build](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit/)
- If no documentation is required, set the correct `ITSAppUsesNonExemptEncryption` value in the final Info.plist to avoid answering the same questions for every upload. If documentation is required, Apple provides an export-compliance code to place in `ITSEncryptionExportComplianceCode`. [Apple: complying with export regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)

**RideHorizon implication:** HTTPS and Apple-provided security features do not justify guessing the answer. Use Apple's question flow and, if uncertain, obtain export/legal advice. The operational gotcha is leaving the Info.plist declaration absent and discovering “Missing Compliance” only after the upload.

## TestFlight review versus public App Review

- Internal TestFlight testing does not substitute for public App Review. TestFlight builds expire after 90 days. External testing may require TestFlight App Review; Apple's current help says the first build added to an external group is reviewed, while later builds may not receive a full review. [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- TestFlight apps must still be intended for public distribution and comply with the App Review Guidelines. Betas and trial versions belong on TestFlight, not the public App Store. [App Review Guidelines 2.2](https://developer.apple.com/app-store/review/guidelines/#beta-testing)
- A TestFlight approval is not approval for sale. When ready for public distribution, complete the App Store metadata, select a processed build, add it to a draft submission, and submit it to public App Review. [Apple: submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app), [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

## Likely sequencing for RideHorizon

1. Finish stability and safety testing in internal TestFlight.
2. Implement the privacy-audit blockers: third-party-AI consent/withdrawal, privacy manifest, log/retention fixes, and deletion/contact path.
3. Publish support and privacy pages, and add the privacy link inside the app.
4. Audit the final binary's SDKs, manifests, entitlements, background modes, usage strings, icon, bundle ID, version, and build number.
5. Complete DSA trader verification and choose initial storefronts deliberately.
6. Prepare exact App Privacy answers, content-rights declaration, new age-rating questionnaire, category, description, keywords, screenshots, price, tax category, and manual release.
7. Produce a release-mode reviewer test route and keep production backends live.
8. Upload with Xcode 26 or later / iOS 26 SDK or later, validate, resolve export compliance, and test that exact processed build in TestFlight.
9. Submit the same tested build to public App Review with precise notes and reviewer access.
10. Use manual release for the first version so approval does not automatically publish before support and monitoring are ready.

## Official source index

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Upcoming App Store submission requirements](https://developer.apple.com/news/upcoming-requirements/)
- [App Store Connect: submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [App Store Connect: required metadata properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/)
- [App Store Connect: platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [App Store Connect: app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [App Store Connect: screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [App Store Connect: manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple: App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple: privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple: third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [Apple: export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
- [Apple: Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
- [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

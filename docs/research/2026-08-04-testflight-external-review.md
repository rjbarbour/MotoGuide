# TestFlight external review for RideHorizon

Date checked: 2026-08-04
Scope: first private external TestFlight group for iPhone build `0.12.4 (20260804.0246)`
Sources: current official Apple documentation, plus the repository's current release and TestFlight records

## Direct answers

### Where the Support URL is

The Support URL is App Store version metadata, not TestFlight test information. In App Store Connect, use:

**Apps → RideHorizon → Distribution → select the iOS version under iOS App → App Information → Support URL**

Apple's current navigation instructions say to select the app version in the sidebar; the Support URL is one of that version's platform-specific properties. It is required for a public App Store product page and can be localised. [Apple: view and edit app information](https://developer.apple.com/help/app-store-connect/create-an-app-record/view-and-edit-app-information) [Apple: platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

The intended RideHorizon value is:

`https://ridehorizon.digitalmercenaries.ai/support`

That URL returned HTTP 200 over HTTPS on 2026-08-04 and contains a monitored email contact, safety guidance and a privacy-policy link. Apple says a Support URL should give users an easy way to contact the developer. Before the public App Store submission, adding the company's registered address and a support telephone number would reduce ambiguity against Apple's more detailed field description; it is not part of the TestFlight review form. [Apple: App Review Guidelines 1.5](https://developer.apple.com/app-store/review/guidelines/#developer-information)

### What starts external TestFlight review

Creating a private external group alone does not submit the build. The operational trigger is:

1. Create or select the external group.
2. Add the build.
3. Complete **What to Test** and the required TestFlight review information.
4. Click **Submit Review**.

Apple then reviews the build and accompanying metadata. The first submitted build requires a full TestFlight App Review; later builds for the same version might not. [Apple: invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/) [Apple: TestFlight App Review](https://developer.apple.com/help/glossary/testflight-app-review/)

### When external testers can install

External testers cannot begin until Apple approves the build. If **Automatically notify testers** was selected, App Store Connect sends the invitations after approval. If it was not selected, the developer must distribute the approved build manually. Testers then accept the email invitation in TestFlight and install the build. [Apple: invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/) [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

### How long review takes

Apple publishes no separate TestFlight-specific service level. Its general App Review statistic is that 90% of submissions are reviewed in less than 24 hours, but that is an average across App Review submissions, not a guarantee for this beta. Incomplete submissions can take longer. The practical plan should therefore allow at least one to two working days and avoid promising testers a precise start time. [Apple: App Review](https://developer.apple.com/app-store/review/)

## What Apple evaluates

Published fact: a TestFlight beta must be intended for eventual public distribution and comply with the App Review Guidelines. Apple reviews both the binary and its accompanying metadata. This is a narrower release decision than the final public App Store submission, but not a lower policy standard. [Apple: App Review Guidelines 2.2](https://developer.apple.com/app-store/review/guidelines/#beta-testing) [Apple: invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

In practical terms, Apple needs to be able to install the app, understand what it does, reach the principal functionality using the supplied instructions, and confirm that the observed behaviour and data handling match the metadata and permissions.

## Common review issues and RideHorizon assessment

Apple does not publish a ranked list limited to TestFlight rejections. The categories below are Apple's published common App Review issues, followed by a RideHorizon-specific assessment.

| Review issue | Apple's rule or evidence | RideHorizon assessment on 2026-08-04 | Mitigation before submission |
| --- | --- | --- | --- |
| Crashes, obvious bugs, incomplete information or an unavailable backend | Apple says more than 40% of unresolved review issues concern App Completeness. Apps must be tested on-device, review access must work and backends must be running. [Apple: App Review](https://developer.apple.com/app-store/review/) [Guideline 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness) | **Low to medium risk.** The exact build has passed internal TestFlight use and the project records successful device, proxy, fact and Premium Voice checks. The remaining external risk is service availability during review. | Keep the production proxy and providers running. Re-run one stationary Test Mode fact and Premium Voice smoke check on the exact TestFlight build immediately before submission. |
| Reviewer cannot reach the core experience | Apple asks for special settings, account information and instructions; missing information may delay or fail review. [Apple: App Review](https://developer.apple.com/app-store/review/) | **Low risk if the current notes are pasted.** Test Mode provides sample location changes without a ride, account, token, Bluetooth hardware or credential. | Use the current Review Notes from `APP_STORE_CONNECT_TEST_INFORMATION.md`; confirm they say Test Mode is **off by default** and give the exact path to enable it. |
| Broken privacy or support links | Apple identifies broken links as a common issue and requires privacy and support access. [Apple: App Review](https://developer.apple.com/app-store/review/) | **Low risk for the URLs.** Both intended HTTPS URLs returned HTTP 200 on 2026-08-04. The support page has email contact; the privacy policy names the controller, providers, retention and rights. | Enter the URLs with `https://`. Consider adding the registered address and support phone to the support page before public App Store submission. |
| Inaccurate or stale metadata | Metadata, descriptions and privacy information must accurately describe the current experience. [Guideline 2.3](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata) | **Medium risk until manually confirmed.** The repository copy is current, but App Store Connect must contain the regenerated Review Notes, Beta App Description and What to Test for this build. | Compare the live fields with `APP_STORE_CONNECT_TEST_INFORMATION.md` before pressing Submit Review. Do not claim navigation, safety or emergency functionality. |
| Location and background execution are unexplained or used outside their intended purpose | Location must be directly relevant, explained and consented to; background services may only be used for their intended purposes. [Guideline 5.1.5](https://developer.apple.com/app-store/review/guidelines/#location-services) [Guideline 2.5.4](https://developer.apple.com/app-store/review/guidelines/#software-requirements) | **Low to medium risk.** Place awareness directly depends on location. The current purpose strings explain foreground and background use, and tracking is tied to Start ride/End ride. Reviewers may still scrutinise Always/background location because it is sensitive. | Keep the Review Notes' plain-language explanation. In Test Mode, review does not depend on granting background location. Ensure ending a ride visibly stops tracking. |
| Privacy policy, consent or App Privacy declarations do not match actual third-party processing | Apple requires a privacy policy in metadata and in the app, explicit permission before sharing personal data with third-party AI, accurate purpose strings, and accurate data-practice disclosures. [Guidelines 5.1.1 and 5.1.2](https://developer.apple.com/app-store/review/guidelines/#privacy) | **Medium administrative risk.** The app has explicit Allow AI / on-device-only choices and the policy describes OpenAI and ElevenLabs. App Store Connect's App Privacy answers still need to be confirmed as complete and published against the final data-flow audit. | Confirm the HTTPS policy URL, complete and publish the App Privacy answers from the privacy audit, and verify that declining AI still leaves Names Only and Apple Voice usable. Apple documents App Privacy as an App Store distribution requirement; it does not identify it separately as the trigger for TestFlight review, but consistency still matters under the Guidelines. [Apple: manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/) |
| Safety risk from device interaction while riding | Apps must not urge people to use devices in a way that risks physical harm. [Guideline 1.4.5](https://developer.apple.com/app-store/review/guidelines/#physical-harm) | **Low risk with current positioning.** The beta copy says setup and settings changes must be done while stopped, RideHorizon is not navigation or emergency software, and the reviewer can test while stationary. | Retain this wording in onboarding, beta description and review notes. Do not instruct Apple or testers to interact with the phone while moving. |
| Placeholder or misleading content; insufficient lasting value | Apple lists placeholder content, misleading claims and insufficient functionality among common issues. [Apple: App Review](https://developer.apple.com/app-store/review/) | **Low risk for TestFlight.** The app has a coherent location-to-announcement function and no known credential or invite placeholder. Cosmetic onboarding issues logged for later do not appear to prevent use. | Do not expose debug-only instructions, stale MotoGuide branding or non-functional controls in the submitted binary or metadata. |
| Third-party content rights | The developer must own or license included content and be permitted to use third-party services. [Guideline 5.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property) | **Low risk if existing attribution records are accurate.** The project retains onboarding-image attribution and the AI providers are named. | Keep attribution evidence. Ensure any photo displayed in the build is covered by the recorded licence and that provider use remains within contract terms. |

## Overall judgement

RideHorizon appears likely to pass its first TestFlight App Review without a code change. The key remaining work is administrative and operational:

1. Confirm the live TestFlight metadata exactly matches the current repository copy.
2. Confirm the App Privacy answers are complete and published; this is also a project release gate.
3. Run one short exact-build Test Mode smoke check for Short Facts and Premium Voice, then keep the proxy available.
4. Create the private external group, add build `0.12.4 (20260804.0246)`, and click **Submit Review**.
5. Wait for approval before expecting external testers to see or install the build.

The phrase **mandatory evidence passes** in the RideHorizon beta pack is an internal project safety/release gate, not an App Store Connect status or Apple form. Apple does not ask to see that evidence record. If any listed field/background/audio checks remain unrecorded, the Account Holder can still technically submit the beta, but doing so explicitly accepts that residual project risk.

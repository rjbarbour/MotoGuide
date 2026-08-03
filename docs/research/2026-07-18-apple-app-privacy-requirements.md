# Apple App Store privacy requirements relevant to RideHorizon

**Research date:** 2026-07-18
**Scope:** Apple App Store Connect privacy-label definitions and App Review privacy requirements relevant to RideHorizon. Sources are official Apple documentation only. This is implementation and submission guidance, not legal advice.

## Bottom line

Apple's privacy label is based on what the app, the developer, and relevant third parties **collect**, not merely what iOS permissions the app requests. For the label, Apple defines collection as transmitting data off the device in a form that the developer or a third party can access for longer than is necessary to service the request in real time. Data kept only on the device is not collected for this purpose. Data sent off device but immediately discarded after servicing the request can also fall outside the disclosure requirement. [Apple: App privacy details — Data collection and additional guidance](https://developer.apple.com/app-store/app-privacy-details/)

The practical RideHorizon audit therefore turns on four facts for every outbound request:

1. exactly what leaves the phone;
2. whether RideHorizon, its infrastructure, or a provider retains it beyond the live request;
3. whether it is associated with an account, device, App Attest key, IP address, or other record; and
4. whether a third-party AI provider receives personal data.

The last point has a separate App Review consequence. Apple requires an app to clearly disclose where personal data is shared with third parties, **including third-party AI**, and obtain explicit permission before sharing it. A privacy-policy entry or privacy label alone is not a substitute for that permission. [App Review Guidelines 5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)

## What Apple means by “collect”

Apple says:

- data must be declared even when it is collected only for app functionality rather than advertising or analytics;
- “collect” means transmitting data off device in a way that permits access for longer than necessary to service the transmitted request in real time;
- data processed only on device is not collected and does not need to appear in the label;
- an off-device authentication token, IP address, or request payload that is not retained after the request is serviced need not be declared;
- ongoing collection following a one-time permission request must be disclosed; and
- optional disclosure is a narrow exception whose conditions must **all** be met. It generally covers infrequent, optional, user-initiated submissions outside the app's primary functionality, such as qualifying support or feedback forms. It does not fit RideHorizon's routine location/fact flow.

Source: [Apple: App privacy details](https://developer.apple.com/app-store/app-privacy-details/).

App Store Connect responses are made at app level and must cover all supported platforms. If one platform collects more data, Apple says to answer in the most comprehensive and inclusive way. The developer must keep the answers current and include relevant practices of third-party code integrated into the app. [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)

## Relevant Apple data categories

| Apple category | Apple definition or rule | RideHorizon audit implication |
|---|---|---|
| **Precise Location** | Location with the same or greater resolution as latitude/longitude with three or more decimal places. | Declare when precise coordinates leave the phone and are retained beyond real-time processing by RideHorizon or a provider. Merely using Core Location on device does not trigger the label. |
| **Coarse Location** | Location at lower resolution than latitude/longitude with three or more decimal places, including approximate location. | A retained town, county, region, or similarly coarsened place is best assessed as Coarse Location. Apple specifically says that if precise location is immediately de-identified and coarsened before storage, declare Coarse Location rather than Precise Location. |
| **Other User Content** | Any other user-generated content. Apple says generic free-form text fields map here. | A retained custom fact-focus or custom-instructions field normally maps here. Apple says the developer need not declare every sensitive fact a user might choose to type into a generic free-form field. If the text stays on device, or is only transiently processed under Apple's real-time rule, it is not collected for the label. |
| **Device ID** | The advertising identifier or another device-level ID. | A retained App Attest key identifier/public-key record or installation-level identifier is likely Device ID. This classification is an inference from Apple's broad definition and App Attest's per-device key model; Apple does not publish an App-Attest-specific privacy-label answer. |
| **User ID** | An account ID, assigned user ID, customer number, or another user/account-level ID identifying a particular user or account. | Declare if the proxy or app assigns a persistent account-level identity. Do not call an account ID a Device ID merely because it is used from a device. |
| **Product Interaction** | App launches, taps, clicks, scrolling, listening/viewing activity, saved items, or other information about interaction with the app. | Declare only if these events leave the device and are retained. Local settings, local UI state, and local logs are not collected for the label. |
| **Crash Data** | Crash logs. | Declare if RideHorizon or an integrated service receives retained crash reports. Apple's own collection is treated separately, as explained below. |
| **Performance Data** | Launch time, hang rate, energy use, or similar performance data. | Declare if retained by RideHorizon or a provider. |
| **Other Diagnostic Data** | Other data collected to measure technical diagnostics related to the app. | Proxy diagnostic events, network failure details, or technical logs may fit here if transmitted and retained. The category depends on the contents and purpose, not the filename “log.” |

Definitions: [Apple: App privacy details — Types of data](https://developer.apple.com/app-store/app-privacy-details/).

### Location nuance

Apple distinguishes use from collection. Live GPS used only on the phone does not appear on the label. If RideHorizon reverse-geocodes locally and sends only a town/county name to its fact service, assess the transmitted and retained place data as Coarse Location. If exact coordinates are sent and retained, assess Precise Location. If exact coordinates are sent only to service the live request and neither RideHorizon nor a provider keeps them in readable form beyond that request, Apple's transient-processing guidance says they need not be disclosed on the label.

This label analysis does not remove the separate requirement to explain location use, notify the user, and obtain consent before collecting, transmitting, or using location data. Apple requires Location Services to be directly relevant to the app and the purpose to be explained in the app. [App Review Guidelines 5.1.5](https://developer.apple.com/app-store/review/guidelines/#location-services)

### Free-form rider instructions

Apple says a generic free-form text field should be represented as **Other User Content**, and the developer is not responsible for listing every possible type of information a user may voluntarily type into it. If the app specifically asks for a named data type, such as an email address, the named category must be used instead. [Apple: App privacy details — free-form fields](https://developer.apple.com/app-store/app-privacy-details/)

For RideHorizon, custom fact focus or custom instructions should therefore be treated as Other User Content when retained off device. Likely purposes are App Functionality and, if the text is used to tailor results to the rider, Product Personalization.

## Selecting data-use purposes

Apple asks for the purpose of each collected data type. The relevant choices are:

- **App Functionality:** authenticating users, enabling features, preventing fraud, implementing security, maintaining uptime, minimizing crashes, improving scalability/performance, or customer support;
- **Product Personalization:** customizing recommendations, content, or what a user sees;
- **Analytics:** evaluating user behaviour, measuring feature effectiveness or audience characteristics, or planning features;
- **Other Purposes:** uses not covered by the listed purposes.

Source: [Apple: App privacy details — Data use](https://developer.apple.com/app-store/app-privacy-details/).

Likely RideHorizon mappings, subject to the code and retention audit:

| Data/use | Likely purpose |
|---|---|
| Place/location sent to generate an announcement | App Functionality; Product Personalization if rider preferences tailor the result |
| Custom fact focus/instructions | App Functionality and Product Personalization |
| App Attest identifier/public key/receipt | App Functionality, because Apple expressly includes authentication, fraud prevention, and security measures |
| Crash or diagnostic events used only to fix reliability | App Functionality; add Analytics if the same events are used to evaluate behaviour, feature effectiveness, or audience characteristics |
| UI interaction events used to assess feature usage | Analytics |

Do not choose Analytics merely because data is logged. Apple's definition depends on how the data is used.

## Data linked to the user

Apple asks whether each collected data type is linked to a user's identity through an account, device, or other details. Apple says collected data is often linked unless the developer or partner applies protections **before collection**, such as removing direct identifiers and breaking the linkage so it cannot be restored. To call data not linked, the developer must also avoid later re-identification and avoid joining it to datasets that enable identification. Apple notes that information treated as personal information or personal data under relevant law is considered linked. [Apple: App privacy details — Data linked to the user](https://developer.apple.com/app-store/app-privacy-details/)

Conservative RideHorizon application:

- if a location, custom instruction, diagnostic event, or interaction is stored against an App Attest record, installation ID, account, stable device record, or retained IP-derived record, answer **linked** unless the implementation can demonstrate pre-collection de-identification and no later re-linking;
- merely omitting a person's name is not enough if the record remains tied to a stable device or account;
- genuinely aggregate, irreversibly de-identified data can be not linked only if RideHorizon and its providers do not attempt to re-identify it or combine it with identifying datasets.

## Tracking and App Tracking Transparency

Apple's privacy-label definition of **tracking** is narrower than ordinary security, analytics, or request correlation. Tracking means either:

- linking user/device data from the app with data from other companies' apps, websites, or offline properties for targeted advertising or advertising measurement; or
- sharing user/device data with a data broker.

Sharing location with a data broker is Apple's explicit example of tracking. An SDK can cause tracking even when the developer does not use its advertising capability, if the SDK repurposes app data for cross-company ad targeting or measurement. [Apple: User privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/)

App Attest security checks, ordinary fact-generation requests, and first-party reliability logging are not tracking merely because they use a persistent identifier. They become tracking only if the Apple definition above is met. On the present product description, RideHorizon should be able to answer **No, not used for tracking**, provided neither its providers nor SDKs use the data for cross-company advertising/measurement or share it with a data broker.

ATT permission is required only if RideHorizon tracks under Apple's definition or accesses the advertising identifier. Apple says IDFV can be used across apps from the same content provider without ATT, but it cannot be combined with other-company data to track users. [Apple: User privacy and data use — ATT](https://developer.apple.com/app-store/user-privacy-and-data-use/)

## App Attest and identifiers

Apple's App Attest implementation guidance says:

- the app generates a unique hardware-backed key pair for each user account on each device;
- the app persistently stores the key identifier;
- the attestation object and key identifier are sent to the developer's server; and
- after verification, the server stores the public key and receipt and associates the key with the user for the specific device so later assertions can be checked.

Sources: [Apple: Establishing your app's integrity](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity) and [Apple: Validating apps that connect to your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server).

Apple does not publish a statement saying “App Attest equals Device ID” for App Store Connect. However, where RideHorizon retains an App Attest key identifier or a server record that distinguishes a specific app instance/device over time, **Device ID** is the defensible privacy-label category. Use **App Functionality** as the purpose because the record implements authentication, fraud prevention, and security. Treat it as linked when it is associated with a user, account, stable device record, or other identifying data. App Attest does not by itself imply advertising tracking or require ATT.

The audit should record separately:

- key identifier retention;
- public-key and receipt retention;
- whether the record is associated with an account or only an installation/device;
- server challenge retention;
- assertion counters and security-event logs;
- retention/deletion periods; and
- whether IP addresses are retained alongside the record.

Apple warns that retained IP addresses may need to be declared as precise location, coarse location, device ID, or diagnostics depending on how they are used. [Apple: App privacy details — IP addresses](https://developer.apple.com/app-store/app-privacy-details/)

## Diagnostics, crash data, and Apple services

If RideHorizon integrates a crash-reporting or analytics SDK, the developer is responsible for the SDK's collection and tracking behaviour. Apple recommends checking the SDK developer's practices when uncertain. [Apple: User privacy and data use — FAQ](https://developer.apple.com/app-store/user-privacy-and-data-use/)

For Apple's own frameworks and services, Apple draws a boundary:

- if the developer receives data about the app from an Apple framework or service, the developer should declare what it receives and how it uses it;
- the developer is not responsible for declaring data Apple itself collects.

Source: [Apple: App privacy details — Apple frameworks and services](https://developer.apple.com/app-store/app-privacy-details/).

Accordingly, do not automatically declare Crash Data merely because Apple can collect crash reports or App Analytics. Declare Crash Data when RideHorizon or a partner receives retained crash logs. Similarly, declare Product Interaction only when interaction events are transmitted and retained by RideHorizon or a partner, not because taps occur locally.

## Third-party SDKs, processors, and AI services

Apple requires the privacy label to include the practices of third-party code integrated into the app. Developers are responsible for all code included in their app. Privacy manifests can help identify an SDK's declared practices, but they do not replace the developer's App Store Connect answers or due diligence. Xcode combines SDK privacy manifests into a report for preparing a more accurate label. [Apple: Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) and [Apple: User privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/)

Backend processors need the same factual retention check. Apple's collection definition asks whether **the developer or third party** can access transmitted data beyond the live request. Therefore, if a fact-generation, speech, hosting, logging, or security provider retains a RideHorizon payload, identifier, IP address, or diagnostic record beyond real-time servicing, the audit should treat that data as collected even when RideHorizon's own application database does not store it. This is a conservative application of Apple's collection rule; the exact provider retention terms must be verified separately.

Third-party AI also has a rule beyond the label. Apple currently requires:

- clear disclosure of where personal data will be shared with third parties, including third-party AI; and
- explicit permission before that sharing occurs.

Source: [App Review Guidelines 5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing).

For RideHorizon this means the audit should determine whether place/location, rider preferences, custom instructions, IP-derived information, or device identifiers reach an AI provider. If personal data does, an explicit consent step should precede the first third-party AI request, and the app must remain coherent when the user declines. Apple's guidelines also say apps must respect permission choices and, where possible, provide alternatives when protected-data access is declined. [App Review Guidelines 5.1.1(ii)–(iv)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)

## Privacy-policy requirements

Apple requires a publicly accessible Privacy Policy URL in App Store Connect for every app. The User Privacy Choices URL is optional. App Store Connect answers are published on the product page once the page is live. [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)

The App Review Guidelines add that the privacy policy link must also be easily accessible **inside the app**. The policy must clearly and explicitly:

1. identify what the app/service collects, how it collects it, and every use;
2. confirm that third parties receiving user data provide the same or equal data protection required by the policy and Apple's guidelines; and
3. explain retention/deletion, how consent can be withdrawn, and how deletion can be requested.

Source: [App Review Guidelines 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage).

Apple also requires user consent for collection of user or usage data, an understandable way to withdraw consent, and complete purpose strings. If the app supports account creation, it must support account deletion from within the app. [App Review Guidelines 5.1.1(ii) and 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)

## Audit decision table for RideHorizon

Use this sequence for each actual data flow:

| Question | If yes | If no |
|---|---|---|
| Does the data leave the device? | Continue. | It is not collected for the App Store privacy label. |
| Can RideHorizon or any provider access it beyond the time required to service the live request? | It is collected; select a data category and purpose. | Apple's transient-processing exception may apply; document evidence of non-retention. |
| Is exact location retained? | Precise Location. | Assess whether a retained place or coarsened coordinate is Coarse Location. |
| Is generic rider-entered free text retained? | Other User Content. | No label entry for that field if on-device or truly transient. |
| Is a stable device/app-instance security identifier retained? | Likely Device ID; purpose App Functionality. | No identifier disclosure solely for an ephemeral token that is not retained. |
| Are UI events retained? | Product Interaction; usually Analytics. | Local interaction alone is not collected. |
| Are crash/performance/technical records retained? | Crash Data, Performance Data, or Other Diagnostic Data as applicable. | Apple-only or on-device diagnostics do not automatically require a declaration. |
| Can the record be connected through an account, device, IP-derived record, or other identifying data? | Mark linked unless genuine pre-collection de-identification prevents re-linking. | It may be not linked if RideHorizon and its providers cannot and do not re-identify it. |
| Is it joined with other-company data for ads/measurement or sent to a data broker? | Tracking; ATT may be required. | Answer not used for tracking. |
| Is personal data shared with third-party AI? | Disclose where and obtain explicit permission before sharing. | No AI-sharing permission is triggered by that flow. |

## Official sources

- [Apple: App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/), accessed 2026-07-18.
- [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), accessed 2026-07-18.
- [Apple: App Review Guidelines — Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy), accessed 2026-07-18.
- [Apple: User privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/), accessed 2026-07-18.
- [Apple: Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/), accessed 2026-07-18.
- [Apple: DeviceCheck](https://developer.apple.com/documentation/devicecheck), accessed 2026-07-18.
- [Apple: Establishing your app's integrity](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity), accessed 2026-07-18.
- [Apple: Validating apps that connect to your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server), accessed 2026-07-18.

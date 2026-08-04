# RideHorizon App Privacy answer audit

**Research date:** 2026-08-04
**Scope:** Release build `0.12.4 (20260804.0246)`, the current iOS and fact-proxy source, and the current public privacy policy. This is an App Store Connect classification audit, not legal advice.

## Bottom line

RideHorizon cannot accurately answer **No, we do not collect data**. Apple does not treat information kept only on the iPhone as collected. Apple also excludes request data that is sent off-device and discarded as soon as the request is serviced. However, RideHorizon and its providers retain some information beyond the live request:

- OpenAI may retain the place prompt, custom instructions, and generated response in abuse-monitoring logs for up to 30 days under its default API controls.
- The RideHorizon database retains a pseudonymous installation-derived hash, short-lived session records, and per-installation fact/speech usage counts.
- The RideHorizon proxy retains limited technical request logs.
- ElevenLabs retains text and speech output by default unless the production account is entitled to, and actually uses, Zero Retention Mode. The request parameter alone does not prove that entitlement.

The current conservative privacy-manifest categories are therefore substantially correct. The recommended App Store Connect answers are:

| Data type | Collected? | Purposes | Linked? | Tracking? |
|---|---:|---|---:|---:|
| Coarse Location | Yes | App Functionality; Product Personalisation | No, subject to the conditions below | No |
| Other User Content | Yes | App Functionality; Product Personalisation | No, subject to the conditions below | No |
| Device ID | Yes | App Functionality | Yes | No |
| Product Interaction | Yes | App Functionality | Yes | No |
| Other Diagnostic Data | Yes | App Functionality | No | No |
| Other Data Types | Yes, conservatively | App Functionality | Yes, conservatively | No |

Do not select Precise Location, Analytics, Crash Data, Audio Data, User ID, or any advertising/tracking purpose for the audited build.

## Apple’s controlling definitions

Apple defines collection as transmitting data off the device and retaining it in readable form for longer than it takes the developer or a third-party partner to service the request. Apple explicitly says that data processed only on the device is not collected. It also says that an authentication token, IP address, or request payload sent to a server and not retained after servicing the request need not be disclosed. [Apple: App privacy details](https://developer.apple.com/app-store/app-privacy-details/)

Apple requires the answers to include relevant third-party practices. It defines location below three-decimal latitude/longitude resolution, including approximate location, as Coarse Location. It defines a device-level identifier as Device ID, app-use events as Product Interaction, and technical diagnostic information as Other Diagnostic Data. [Apple: App privacy details — data types and additional guidance](https://developer.apple.com/app-store/app-privacy-details/)

Apple says data is linked when it remains associated with identity through an account, device, or other details. Removing a name is not enough if a persistent device-level relationship remains. Tracking is narrower: it means combining app data with other-company data for targeted advertising or advertising measurement, or sharing it with a data broker. [Apple: App privacy details — linked data and tracking](https://developer.apple.com/app-store/app-privacy-details/)

## Current data-flow findings

### Precise and coarse location

**Fact:** Core Location coordinates, speed, and ride history stay on the iPhone. `PlaceFactRequest` sends reverse-geocoded place names rather than latitude/longitude. The request contains the announced boundary plus a minimised hierarchy such as town, county, region, and country. Local diagnostics record location accuracy and sample age, but their typed schema cannot contain coordinates or place names.

**Fact:** The proxy does not persist the fact request body. It builds an OpenAI prompt containing the place hierarchy and sends that prompt to OpenAI. OpenAI states that `/v1/chat/completions` has no application-state retention, but default abuse-monitoring logs may contain prompts and responses for up to 30 days. [OpenAI: API data controls](https://platform.openai.com/docs/models/default-usage-policies-by-endpoint)

**Conclusion:** Do not declare Precise Location. Declare Coarse Location because the place hierarchy can be retained by OpenAI beyond live request processing. Select App Functionality and Product Personalisation. Answer not linked only while the proxy continues to omit the installation identifier, session token, IP address, user ID, and request ID from the OpenAI payload, does not persist request content, and does not subsequently correlate provider history with installation records.

### Other User Content

**Fact:** A rider may enter custom fact instructions and configure home/familiar regions and interests. These values remain local until an AI fact is requested, then they are sent through the proxy in the OpenAI prompt. The proxy does not persist them, but OpenAI may retain that prompt under its default controls.

**Conclusion:** Declare Other User Content for the optional free-form instructions. Select App Functionality and Product Personalisation. The same not-linked conditions as Coarse Location apply.

### Device ID and access records

**Fact:** The app generates a random `rh-ios-<UUID>` installation identifier and stores it in the iOS Keychain. It sends the value to the proxy in `X-RideHorizon-Device-Id`. The current fallback flow does not store the raw UUID in PostgreSQL, but it stores a stable SHA-256-derived quota-subject value in session and per-installation usage rows. That stable value can recognise requests from the same installation. Expired session records are retained for up to 30 days; usage buckets for up to three days. The raw identifier can also remain in the proxy’s in-memory rate limiter for about 60 seconds.

**Conclusion:** Declare Device ID, linked, for App Functionality. Hashing the identifier protects the raw value but does not make the stable device relationship anonymous. App Attest is not active in the audited server flow, so do not describe App Attest collection as current behaviour.

### Product Interaction

**Fact:** Per-installation daily buckets retain the number of fact requests and number of speech characters. Session records retain creation, expiry, and last-use timestamps. These values are tied to the stable installation-derived hash and used to enforce service limits.

**Conclusion:** Declare Product Interaction, linked, for App Functionality. Do not select Analytics: the audited implementation uses these records for quota enforcement and security, not to evaluate user behaviour, feature effectiveness, or audience characteristics.

### Diagnostics and local logs

**Fact:** The proxy application logs fact-request route, status, duration, and a random request ID. Optional provider diagnostics log status, duration, response size, boundary type, fact mode, and text/fact length, but not request bodies, place names, device IDs, tokens, or IP addresses. The exact production flag and Fly log-retention period still need operational confirmation.

**Conclusion:** Declare Other Diagnostic Data, not linked, for App Functionality. If production infrastructure is found to retain the same entries with client IP or installation identifiers, change the answer to linked.

**Fact:** Ride diagnostics stored in `RideDiagnosticsStore` remain in the app’s excluded-from-backup cache and are not uploaded automatically. They leave the phone only if the rider chooses to export and share them. Apple says on-device-only data is not collected.

**Conclusion:** Local logs alone do not require Product Interaction or Diagnostics disclosure. A genuinely optional, user-initiated support submission may also qualify for Apple’s narrow optional-disclosure exception, but that exception should be reassessed if automatic diagnostic upload is added.

### Other Data Types and IP processing

**Fact:** The proxy and hosting path process IP addresses. The application rate limiter keeps an IP-derived or device-derived identity in memory for approximately 60 seconds. The application does not write IP addresses to its own logs. Cloudflare and Fly necessarily process connection metadata; their exact retained edge-log fields and periods have not been proved in this audit. Session token hashes, failure reasons, and security timestamps are also retained but do not have a perfectly explicit Apple category beyond the declared Device ID/Product Interaction categories.

**Conclusion:** Keep Other Data Types, linked, for App Functionality in this release as a conservative cover for retained connection/security data whose exact infrastructure classification is not yet proven. Apple says retained IP addresses should be classified according to use, for example as location, Device ID, or diagnostics. Once Cloudflare/Fly retention is verified, this catch-all may be removable or reclassified without changing the underlying no-tracking answer.

### Premium Voice

**Fact:** RideHorizon sends announcement text, not microphone audio, to ElevenLabs. The proxy adds `enable_logging=false`. ElevenLabs says its default is retention and that Zero Retention Mode is available to selected Enterprise customers; when active, TTS text and output are not sent to long-term storage. It recommends checking request history to verify that the mode is active. [ElevenLabs: Zero Retention Mode](https://elevenlabs.io/docs/eleven-api/resources/zero-retention-mode)

**Conclusion:** Do not declare Audio Data because the app neither records nor uploads rider audio. The announcement text is derived service content, already covered where it contains place or rider content. Do not describe ElevenLabs processing as ephemeral until the production account’s request history or entitlement verifies Zero Retention Mode.

## “Linked” and “anonymous” in plain language

The AI-content path is designed to be **unlinked**, not fully anonymous in every respect. OpenAI receives place and preference content under Digital Mercenaries’ API account, but the prompt does not carry RideHorizon’s installation identifier or a user account. That supports not-linked answers for Coarse Location and Other User Content.

The access/usage path is **pseudonymous**. RideHorizon has no customer account, name, or email, but the retained hash consistently represents one app installation. Apple’s linked-data definition includes linkage through a device, so Device ID and Product Interaction should be marked linked.

## Conditions that would change the answers

Re-audit before submission if any of these occurs:

- request bodies, prompts, speech text, device IDs, tokens, or IP addresses are added to application logs;
- a crash/analytics SDK or automatic diagnostic upload is added;
- App Attest verification and persistent App Attest installation records are enabled;
- OpenAI or ElevenLabs account retention controls change;
- proxy requests start sending coordinates rather than place names;
- provider requests include a user/device identifier or are correlated with retained provider history; or
- Cloudflare/Fly edge logging is enabled with retained client identifiers.

## Source files inspected

- `RideHorizon/PlaceFactRequest.swift`
- `RideHorizon/ProxyFactGenerator.swift`
- `RideHorizon/KeychainCredentialLoader.swift`
- `RideHorizon/RideDiagnosticsStore.swift`
- `RideHorizon/PlaceFactCache.swift`
- `RideHorizon/PrivacyInfo.xcprivacy`
- `fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/FactController.java`
- `fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/OpenAiService.java`
- `fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/ElevenLabsSpeechService.java`
- `fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/JdbcSessionAuthority.java`
- `fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/RateLimitFilter.java`
- `fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/RequestInstrumentationFilter.java`
- `fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/PrivacyRetentionCleanup.java`
- `fact-proxy/src/main/resources/db/migration/V2__session_access.sql`
- `fact-proxy/src/main/resources/db/migration/V5__remove_invites_and_fix_fallback_quotas.sql`
- `privacy-site/site/_worker.js`
- `privacy-site/site/index.html`

## Official sources

- [Apple: App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [OpenAI: Data controls in the OpenAI platform](https://platform.openai.com/docs/models/default-usage-policies-by-endpoint)
- [ElevenLabs: Zero Retention Mode](https://elevenlabs.io/docs/eleven-api/resources/zero-retention-mode)

# RideHorizon SAR and erasure operations

**Research date:** 2026-08-04
**RH-062 candidate reconciliation:** 2026-08-21
**Scope:** Current RideHorizon iOS and fact-proxy source, published privacy policy, UK GDPR operational duties, and current first-party provider documentation. This is an operational assessment, not legal advice.

## Bottom line

Digital Mercenaries Limited is the controller for RideHorizon. Fly.io, Cloudflare, OpenAI and ElevenLabs process relevant customer data on its behalf to the extent described by their applicable data-processing terms. The controller remains responsible for answering the rider and for processor compliance; telling a rider merely that processors *may* hold personal information is not a sufficient response to a valid subject access or erasure request.

For a valid request, Digital Mercenaries must make a reasonable and proportionate search, act on the RideHorizon records it can identify, involve a processor where its assistance is needed, and give a definite response explaining what was found, supplied or erased and any lawful limit. The ICO says a SAR and an erasure request normally require a response without undue delay and within one month. A complex request or multiple requests from the same person can justify up to two additional months, but the requester must be told within the first month. [ICO: subject access](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/subject-access-requests/a-guide-to-subject-access/) [ICO: right to erasure](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/individual-rights/right-to-erasure/)

## Controller and processor responsibilities

- **Legal fact:** a controller determines why and how personal data is processed and bears the highest compliance responsibility, including processing performed by its processors. Processor contracts must require assistance with data-subject rights. [ICO: controllers and processors](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/controllers-and-processors/controllers-and-processors-a-guide/) [ICO: required processor-contract terms](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/accountability-and-governance/contracts-and-liabilities-between-controllers-and-processors-multi/what-needs-to-be-included-in-the-contract/)
- **Implementation fact:** the public policy correctly names Digital Mercenaries Limited as controller and directs privacy requests to `privacy@digitalmercenaries.ai`.
- **Recommendation:** retain an applicable DPA for every processor. OpenAI's current DPA and ElevenLabs' current DPA describe them as processors and require assistance with data-subject requests. Cloudflare's current DPA describes Customer as controller and Cloudflare as processor for covered personal data. Fly says customers needing GDPR compliance must request and sign its pre-signed DPA; verify that Digital Mercenaries has actually executed it. [OpenAI DPA](https://cdn.openai.com/pdf/openai-data-processing-addendum.pdf) [ElevenLabs DPA](https://elevenlabs.io/dpa) [Cloudflare DPA](https://www.cloudflare.com/en-gb/cloudflare-customer-dpa/) [Fly compliance documents](https://fly.io/documents)

## Identity and the current matching gap

### What the product currently does

- The app creates a random raw identifier in the form `rh-ios-<UUID>` and keeps it in the iOS Keychain.
- The fallback access path sends that value to the proxy. The proxy does **not** store the raw value; it stores `SHA-256("fallback:" + normalizedDeviceId)` as a quota-subject hash in session and usage records.
- Usage rows contain daily fact-request and speech-character counts; session rows contain issuance, expiry and last-use data. Usage records are automatically deleted after three days and expired/revoked sessions after 30 days.
- App Attest registration is disabled in the audited server code, so normal beta installations do not have a searchable `rh_installations` record.
- The app does not currently show or export its raw installation identifier. Its privacy-safe diagnostic export deliberately omits device identifiers.

### Consequence

There is currently no reliable user-operable route to match a rider to their pseudonymous Fly database rows. Knowing the rider's name or email does not help because neither is stored. Asking for conventional identity documents would add risk but would not establish which database hash belongs to that person.

The law does not require a controller to acquire extra information solely to identify a data subject where identification is not needed for the processing. If the controller cannot identify the person from its data, it should explain that; rights such as access and erasure apply if the person later supplies additional information that enables identification. [UK GDPR Article 11](https://www.legislation.gov.uk/eur/2016/679/pdfs/eur_20160679_2016-05-04_en.pdf) The ICO also says identity checks must be reasonable and proportionate, and existing verification mechanisms should be preferred to formal ID. [ICO: subject-access identity checks](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/subject-access-requests/a-guide-to-subject-access/)

**Recommendation:** before widening the beta, implement a privacy-request code that the app can display after local device authentication. The server should be able to deterministically match that code to the quota-subject hash without disclosing a session token, API key or App Attest object. Until then, record the limitation and rely on automatic deletion where no reasonable match is possible; do not pretend that an email address identifies a database row.

## Provider-by-provider handling

| System | Current searchable or erasable information | Action for a matched SAR | Action for a matched erasure request | Current limitation |
|---|---|---|---|---|
| **iPhone** | Exact location, displayed address, ride history, settings, cached facts and local diagnostics remain locally. The user controls the device. | Explain that Digital Mercenaries has no remote access to these items. The user may inspect/export available diagnostics. | Direct the user to **Clear Local Data** and, if desired, uninstall the app/revoke iOS permissions. | Local clearing does not send a server or provider deletion request. |
| **RideHorizon PostgreSQL on Fly** | A quota-subject hash, short-lived token hashes, session timestamps, failure reason, and per-day fact/speech usage counts. Request bodies, place names and announcement text are not stored. | Given the raw installation identifier, compute the same hash and query matching session/usage rows. Explain fields and retention. | Delete matching `rh_sessions` and `rh_usage_subject_buckets` rows. App Attest installation/challenge rows would also need deletion if enabled later. Record affected row counts. | There is no production rights endpoint and the current app does not expose the identifier. The admin deletion route only revokes App Attest installation UUIDs and does not address fallback hashes. |
| **Fly infrastructure** | The database volume and its daily snapshots; platform connection/log data may also exist. Fly volume snapshots are retained for five days by default unless configured otherwise. | Search customer-controlled database/app logs first. Ask Fly for DPA assistance only if relevant data cannot be handled through customer controls. | Delete live database rows. Treat any remaining snapshot copy as beyond use until scheduled expiry; document the snapshot period. Contact Fly under the DPA if platform-held data requires action. | Exact Fly platform log fields/retention and the executed DPA have not been verified. [Fly volumes](https://fly.io/docs/volumes/overview/) |
| **Cloudflare** | The Worker code does not create application logs explicitly, but Cloudflare processes IP address, routing and request metadata. Workers Logs, if enabled, have a maximum seven-day retention. Cloudflare distinguishes processor-held Customer Logs/content from Network Data for which it may act as controller. | Check whether Workers Logs/Logpush or other retained Customer Logs are enabled. Search only where a reasonable identifier and time range exist. Use Cloudflare DPA assistance if necessary. | Delete customer-controlled retained logs where possible or instruct Cloudflare for processor-held records. Tell the requester separately about any Cloudflare independent-controller processing relevant to them. | A name/email cannot locate an edge request. Current account logging configuration is unverified. [Cloudflare privacy policy](https://www.cloudflare.com/policies/privacy/) [Workers Logs](https://developers.cloudflare.com/workers/observability/logs/workers-logs/) |
| **OpenAI API** | The last documented live deployment uses `/v1/chat/completions`. The RH-062 candidate moves place facts to `/v1/responses` with `store: false`, so Responses application state is not retained. Default abuse-monitoring logs may still contain prompts and responses for up to 30 days. The prompt contains place hierarchy and rider context but no RideHorizon installation ID, session token or request ID. | The candidate creates no stored Response object for customer-side retrieval or deletion. If a rider supplies sufficiently specific content/time and provider-held abuse-monitoring material could reasonably be located, submit a DPA assistance request to OpenAI. Otherwise explain that provider content is not linked to a RideHorizon identity and expires under OpenAI's retention controls. | Instruct OpenAI under its DPA where the content can be identified; otherwise document why it cannot reasonably be located and the automatic maximum retention. | RideHorizon does not retain a provider request ID or content/time mapping, so a per-rider provider search is normally impossible. The Responses change is not production fact until RH-062 is deployed. [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data) [OpenAI DPA](https://cdn.openai.com/pdf/openai-data-processing-addendum.pdf) |
| **ElevenLabs** | The request sends announcement text with `enable_logging=false`. Unless the account is eligible for Zero Retention Mode, generations can appear in account history with text, audio, time and a history/request ID. History items can be listed and deleted by API; deletion removes text/audio from the live database, while debugging/moderation data and backups can remain, with deleted backup items expiring within 30 days. | First verify whether Zero Retention Mode is truly active by checking that production requests do not appear in history. If history exists, search a narrow time/text range only when the requester supplies enough information to identify their item reliably. | Delete matched history items via ElevenLabs' history-delete API and record IDs/status; use ElevenLabs' DPA assistance for debugging/moderation records where necessary. | RideHorizon stores no ElevenLabs history or request ID and sends no installation ID, so reliable per-rider matching is normally unavailable. [ElevenLabs Zero Retention](https://elevenlabs.io/docs/eleven-api/resources/zero-retention-mode) [List history](https://elevenlabs.io/docs/api-reference/history/list) [Delete history item](https://elevenlabs.io/docs/api-reference/history/delete/) [ElevenLabs DPA](https://elevenlabs.io/dpa) |

## What a response must say

### Subject access

Do not answer only “our processors may hold PII”. The response should state:

1. whether personal data concerning the requester was found;
2. a copy of identifiable personal data found through a reasonable and proportionate search;
3. the purposes, categories, recipients, retention, source, rights and relevant transfer safeguards;
4. which systems were searched and any system where the data could not be linked to them; and
5. a secure delivery method.

### Erasure

The right is not absolute. It commonly applies when data is no longer necessary, consent is withdrawn, legitimate-interest processing is successfully objected to, or processing was unlawful. Exceptions can include legal obligations and establishing, exercising or defending legal claims. If a valid erasure request applies and data was disclosed to recipients, the ICO says each recipient must be informed unless impossible or disproportionate. Backups may remain until overwritten if put beyond use and the requester is told what happens. [ICO: right to erasure](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/individual-rights/right-to-erasure/)

The response should state what was deleted, which processors were instructed, the backup/automatic-expiry timetable, and any data retained with the exact legal reason. If refusing or limiting a request, explain the reason and the right to complain to the ICO and seek a judicial remedy.

## Recommended private-beta procedure

1. Log every verbal or written rights request immediately with received date, requester contact, scope and deadline. Do not log unnecessary ride/location content.
2. Acknowledge promptly and ask only for information needed to match records. Until a privacy-request code exists, ask whether the app is still installed and for approximate dates of AI/Premium Voice use; do not request passports, API keys, access tokens or attestation objects.
3. Search the controller systems first: privacy mailbox, Fly PostgreSQL, relevant Fly logs, and enabled Cloudflare Customer Logs. Record search terms, systems, dates and results.
4. For a SAR, export only matched personal data and redact secrets and other people's data. For erasure, delete matched live rows and make them unavailable from normal backup restoration.
5. Invoke provider DPA assistance only where enough information exists to make a reasonable provider search. Record each ticket/reference and outcome.
6. Respond within one calendar month. If extending by up to two months for complexity or number of requests, notify and explain within the first month.
7. Keep a minimal compliance record of the request, identity/matching method, decisions, searches, provider notices, response date and lawful reason for any refusal. Do not retain a full copy of deleted ride content merely to prove deletion.

## Immediate operational gaps

1. No privacy-request identifier or server-side rights endpoint exists for fallback beta installations.
2. No per-request mapping exists from a RideHorizon installation to OpenAI or ElevenLabs provider records.
3. ElevenLabs Zero Retention entitlement has not been verified.
4. Fly and Cloudflare production log configuration/retention has not been verified.
5. Execution/retention of the Fly DPA has not been verified.
6. There is no written rights-request runbook, request register or response template beyond this research note.

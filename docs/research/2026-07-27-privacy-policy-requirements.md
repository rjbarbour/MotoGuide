# RideHorizon Privacy Policy Requirements

Date: 2026-07-27

Scope: minimum accurate content for a UK-facing iOS privacy policy for the current RideHorizon MVP. This is research, not legal advice. It must be reconciled with the final Release build, production proxy, provider accounts, contracts, and App Store Connect answers before publication.

## Executive finding

A publishable first draft can be written now, but it must use qualified language for provider retention and server deletion until the outstanding production checks are complete.

The minimum policy must identify Digital Mercenaries Limited as the controller; describe each category of information, purpose and lawful basis; identify the recipients; explain international transfers, retention, choices and rights; explain how to complain to the ICO; and provide a monitored privacy contact. Apple additionally requires the policy to explain collection, all uses, third-party protection, retention/deletion, consent withdrawal, and deletion requests.

RideHorizon must not publish any of these claims yet:

- “We do not collect personal data.”
- “ElevenLabs uses zero retention.”
- “All server data is deleted when you clear the app.”
- “OpenAI immediately deletes prompts.”
- “No information leaves your device.”

Those claims would not match the audited product or have not yet been verified.

## 1. Controller identity

Authoritative public Companies House information:

- Legal name: **DIGITAL MERCENARIES LIMITED**.
- Company number: **05428486**.
- Status: Active.
- Registered office: **55 Douglas Road, Esher, Surrey, England, KT10 8BA**.
- Incorporated: 2005-04-19.

Source: [Companies House company overview](https://find-and-update.company-information.service.gov.uk/company/05428486).

Use the full legal name and company number in the policy. The registered office is suitable as the public postal contact unless the company deliberately designates another valid business address.

Still required from the operator:

- choose and monitor a privacy email address;
- choose and publish a support URL;
- confirm whether a Data Protection Officer has been appointed. Do not call the ordinary privacy contact a DPO unless the role formally exists.

## 2. UK transparency content

The ICO says that privacy information for data collected from individuals must always state the organisation's identity and contact details, processing purposes, retention periods, applicable individual rights, and the right to complain to a supervisory authority. It must also state the lawful basis, recipients, international transfers and safeguards, right to withdraw consent, and consequences of not supplying data when applicable. [ICO: what privacy information should we provide?](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/the-right-to-be-informed/what-privacy-information-should-we-provide/)

The ICO says the controller must choose and document its lawful basis before processing starts, and include both the purposes and lawful bases in its privacy information. [ICO: a guide to lawful basis](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/a-guide-to-lawful-basis/)

The Data (Use and Access) Act 2025 amended parts of UK GDPR Articles 13 and 14. Its explanatory notes confirm that Article 13 governs information provided when personal data is collected directly from the person. Nothing identified in those amendments removes RideHorizon’s ordinary transparency duties. [Data (Use and Access) Act 2025, section 77 explanatory notes](https://www.legislation.gov.uk/ukpga/2025/18/notes/division/10/index.htm)

### Minimum policy sections

1. Effective date and scope.
2. Controller legal identity and contact details.
3. A plain-language explanation of how RideHorizon works.
4. Information processed locally on the iPhone.
5. Information sent to the RideHorizon proxy and service providers.
6. Purpose and lawful basis for each processing activity.
7. Recipients/service providers and their roles.
8. International transfers and safeguards.
9. Retention and deletion.
10. User choices, consent withdrawal, and consequences of declining.
11. UK data-protection rights and how to exercise them.
12. Right to complain to the ICO.
13. Security summary.
14. Children.
15. Policy changes.

## 3. Product facts the policy must describe

These facts come from the repository audit dated 2026-07-18 and must be rechecked against the final release.

| Activity | Information | Purpose | Proposed UK lawful basis | Required wording constraint |
|---|---|---|---|---|
| Core on-device place awareness | Exact GPS coordinates, speed, reverse-geocoded address, current-session ride history | Detect place changes and speak announcements | Consent/permission for iOS location access; assess whether UK GDPR applies to purely local app processing in this controller context | Say exact coordinates are processed on device and are not sent to the RideHorizon proxy in the audited flow. Do not imply Apple location/reverse-geocoding services are operated by Digital Mercenaries. |
| Optional AI facts | Town, county, region, country; home/familiar regions; interests; custom fact focus; generated fact | Generate personalised place facts | Consent is the clearest proposed basis because the app provides an explicit optional AI-sharing choice | Name OpenAI. Explain that declining leaves non-AI place announcements available. Explain withdrawal in Settings. |
| Optional premium speech | Announcement text containing a place name, generated fact, or rider-supplied preference text; generated audio | Convert text to speech | Consent is the clearest proposed basis because this disclosure is optional | Name ElevenLabs. Do not say that rider audio is uploaded: the current app uploads text and receives generated audio. |
| Installation access/security | Random installation/device identifier, access credential/token hash, expiry/revocation/last-use timestamps | Authenticate the app, prevent abuse, rate-limit the service | Legitimate interests is a plausible proposed basis: service security and fraud/abuse prevention | Complete and retain a legitimate-interests assessment before relying on this basis. Explain that the identifier is app-generated, not an advertising identifier. |
| Limited proxy diagnostics | Request ID, route, status, duration, provider status, response size; potentially edge-handled IP address | Operate, secure and troubleshoot the service | Legitimate interests is a plausible proposed basis: reliable and secure service operation | State only the fields actually retained in production. Do not claim IP non-retention until Fly edge behaviour is verified. |
| Legal compliance/disputes | Limited relevant records if required | Meet legal obligations, establish or defend claims | Legal obligation or legitimate interests, depending on the purpose | Keep this narrow. It does not justify open-ended retention. |

“Proposed lawful basis” is not a final legal determination. Digital Mercenaries Limited must document the chosen basis for each purpose before publication. In particular, it should complete a legitimate-interests assessment for security and operational records. The ICO says necessity must be targeted and proportionate and cannot be claimed when the purpose can reasonably be met through less intrusive means. [ICO: a guide to lawful basis](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/a-guide-to-lawful-basis/)

## 4. Apple requirements

Apple requires a publicly accessible privacy-policy URL for every iOS app, and requires the developer to declare both its own practices and those of integrated third-party partners in App Store Connect. [Apple: app privacy details](https://developer.apple.com/app-store/app-privacy-details/) [Apple: manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)

Apple App Review Guideline 5.1.1 requires the privacy-policy link both in App Store Connect and inside the app in an easily accessible place. The policy must:

- identify data collected, how it is collected, and every use;
- confirm that data-sharing third parties provide the same or equal protection;
- explain retention and deletion;
- explain how consent can be revoked and how deletion can be requested.

Apple also requires consent for collecting user or usage data and an understandable way to withdraw it. [Apple App Review Guidelines, section 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy)

The policy and App Store privacy label must agree. Apple defines “collect” for the privacy label as transmitting data off device in a way that permits access for longer than needed to service the real-time request. The audit’s conservative current answer is **Yes, data is collected**. [Apple: app privacy details](https://developer.apple.com/app-store/app-privacy-details/)

### Apple-specific publication gate

- Host the policy at a stable, publicly reachable HTTPS URL with no login.
- Add that URL in App Store Connect.
- Link it inside Settings and the AI consent flow.
- Ensure the page has a real contact route.
- Ensure all links work during review; Apple says broken or placeholder links can block review. [Apple App Review Guidelines, section 2.1](https://developer.apple.com/app-store/review/guidelines/#performance)
- Reconcile the policy with the final App Privacy answers and signed archive.

## 5. OpenAI wording

Safe, supported wording for the current default API configuration:

> When you enable AI facts, RideHorizon sends minimised place information and any relevant preferences or custom fact instructions to OpenAI through our proxy to generate a place fact. OpenAI states that API inputs and outputs are not used to train its models by default unless the customer opts in. Under OpenAI's default API controls, abuse-monitoring logs may contain prompts, responses and related metadata and are retained for up to 30 days, unless a longer period is legally required or reasonably necessary to protect the service or third parties.

OpenAI’s current official data-controls page says:

- API data is not used for training by default unless the customer explicitly opts in;
- default abuse-monitoring logs may contain customer content and are retained for up to 30 days, subject to stated exceptions;
- Zero Data Retention and Modified Abuse Monitoring require approval;
- the Responses API can retain application state for at least 30 days by default, depending on endpoint/configuration.

Source: [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data#default-usage-policies-by-endpoint).

OpenAI’s DPA says OpenAI acts as a processor for Customer Data. For UK Data it incorporates controller-to-processor SCCs amended by the UK Addendum, with OpenAI OpCo, LLC as importer. [OpenAI Data Processing Addendum](https://openai.com/en-GB/policies/data-processing-addendum/)

Must verify before final wording:

- exact production endpoint and whether it creates application state;
- whether `store=false` is explicitly set where applicable;
- whether the production OpenAI organisation has Zero Data Retention or Modified Abuse Monitoring;
- that model-improvement data sharing has not been opted into;
- that the current DPA and UK transfer mechanism bind the correct company account.

Do not state “OpenAI retains data for exactly 30 days.” The supported default claim is “up to 30 days” for abuse-monitoring logs, with the provider’s stated exceptions.

## 6. ElevenLabs wording

The application currently sends `enable_logging=false` for text-to-speech. That flag alone does not prove zero retention.

ElevenLabs says Zero Retention Mode:

- is available to selected Enterprise customers;
- is enabled for eligible text-to-speech API requests using `enable_logging=false`;
- restricts logging of TTS text input and audio output so that those values are not sent to a long-term database;
- should be verified by confirming the requests do not appear in request history;
- may still be restricted at ElevenLabs’ discretion.

Source: [ElevenLabs: Zero Retention Mode](https://elevenlabs.io/docs/eleven-api/resources/zero-retention-mode).

Safe wording until entitlement and history are verified:

> If you select Premium Voice after enabling AI sharing, RideHorizon sends the announcement text to ElevenLabs to generate speech audio. Our request asks ElevenLabs not to log the text or generated audio. Zero Retention Mode is available only to eligible ElevenLabs accounts, so provider retention remains subject to our verified account configuration and ElevenLabs' applicable terms.

Preferred wording after successful production verification:

> If you select Premium Voice after enabling AI sharing, RideHorizon sends the announcement text to ElevenLabs to generate speech audio. The production account uses ElevenLabs Zero Retention Mode for these requests. ElevenLabs states that in this mode TTS text and generated audio are not sent to a database for long-term storage.

Do not describe this as “nothing is retained” or “no data is logged”: ElevenLabs describes specific request/response content restrictions and says “most data” is immediately deleted.

ElevenLabs’ DPA identifies it as a processor for customer personal data, covers text and audio content, and incorporates the UK Addendum for transfers outside the UK. [ElevenLabs Data Processing Addendum](https://elevenlabs.io/dpa)

Must verify before final wording:

- production account plan and explicit Zero Retention Mode eligibility;
- absence of production TTS requests from ElevenLabs request history;
- correct ElevenLabs contracting entity and applicable DPA;
- any subprocessor or regional-processing configuration relevant to the account.

## 7. International transfers

Because OpenAI and ElevenLabs may involve entities outside the UK, the policy must say that personal information may be processed outside the UK, identify the safeguard in plain language, and explain how to obtain further information or a copy where required.

The ICO says a restricted transfer occurs when UK GDPR applies, the organisation initiates a transfer to a separate legal entity outside the UK, and the recipient is outside the UK. Such a transfer needs UK adequacy regulations, appropriate safeguards, or an exception. [ICO: brief guide to international transfers](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/a-brief-guide-to-international-transfers/)

Do not infer the transfer position merely from server geography. The ICO says the service provider’s legal establishment and the parties initiating transfers matter, including subprocessors. [ICO: are we making a restricted transfer?](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/a-guide-to-international-transfers/are-we-making-a-restricted-transfer/)

Provisional policy wording:

> Some service providers may process personal information outside the United Kingdom. Where UK transfer restrictions apply, we use an applicable adequacy regulation or contractual safeguards such as the UK Addendum to the European Commission's Standard Contractual Clauses. Contact us for more information about the safeguards relevant to your information.

Before publication, retain copies of the applicable OpenAI and ElevenLabs DPAs and document whether a transfer-risk assessment/data protection test is needed. Verify Fly.io’s contracting entity, regions, subprocessors and transfer terms separately; this research did not establish them.

## 8. Retention wording

The policy must give actual periods or clear criteria. “We keep data only as long as necessary” is not sufficient by itself: the ICO says the privacy information must state how long data is kept or the criteria used to decide. [ICO: what privacy information should we provide?](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/the-right-to-be-informed/what-privacy-information-should-we-provide/)

Current policy-ready facts, subject to production verification:

- exact location and current ride history: held in memory for the active session by RideHorizon; not sent to the RideHorizon proxy in the audited flow;
- generated fact cache and context-derived cache keys: stored locally for up to 30 days, or until the user clears local data/uninstalls as applicable;
- one-time proxy invites: delete within 24 hours after consumption or expiry under the implemented cleanup schedule;
- expired or revoked legacy proxy credentials: delete after 30 days under the implemented cleanup schedule;
- in-memory rate-limit identities: expire after the 60-second window and are pruned by traffic/scheduled cleanup;
- OpenAI default abuse-monitoring content: up to 30 days, subject to OpenAI’s exceptions and actual account controls;
- ElevenLabs TTS content: do not state a period until Zero Retention Mode is verified, or document the actual non-ZRM provider setting;
- proxy application logs: intended approximately 7 days, but production Fly retention and edge/client-IP handling must be verified;
- installation/security record: an enforceable inactivity/deletion period has not yet been verified.

The public policy must distinguish:

- clearing local information in the app;
- deleting server-side security records;
- provider retention outside Digital Mercenaries’ direct storage.

Do not promise that “Clear Local Data” deletes remote records. The audited control clears local data and credentials only.

## 9. User rights and complaint route

The policy should state, subject to legal limits, the rights to:

- be informed;
- access personal information;
- correct inaccurate information;
- erase information;
- restrict processing;
- data portability where applicable;
- object where applicable;
- withdraw consent at any time without affecting earlier lawful processing.

The exact applicability varies with the lawful basis. The ICO says this must be accurately reflected in the notice, and consent must be as easy to withdraw as to give. [ICO: what privacy information should we provide?](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/the-right-to-be-informed/what-privacy-information-should-we-provide/)

Operational instructions should say:

- revoke iOS Location permission in iOS Settings;
- withdraw optional AI sharing in RideHorizon Settings;
- choose Apple Voice instead of Premium Voice;
- use Clear Local Data for local data;
- contact the monitored privacy address for server-side access, correction, objection or deletion requests.

Because this version has no user account, explain that Digital Mercenaries may need limited information to match a request to an installation. Explicitly tell users never to send an API key, access token, App Attest object, or other secret.

Complaint wording should identify the UK Information Commissioner’s Office and link to [ICO: make a complaint](https://ico.org.uk/make-a-complaint/). Users should be invited to contact Digital Mercenaries first, but the policy must not suggest they lose the right to contact the ICO directly.

## 10. Children and automated decision-making

The current product is intended for adult motorcyclists. State that it is not directed to children and that the company does not knowingly collect children’s information. This should match the App Store age rating and marketing.

The app’s generated place facts do not appear to make decisions producing legal or similarly significant effects. The policy can state that RideHorizon does not use personal information for solely automated decisions with legal or similarly significant effects. Reassess before adding profiling, safety scoring, pricing, eligibility decisions, or adaptive preference models.

## 11. Publication blockers and required manual confirmations

The policy can be drafted and hosted automatically, but the operator must make or verify these decisions:

1. Select a monitored privacy email address and support URL.
2. Confirm whether a DPO exists.
3. Approve the lawful-basis map and complete the legitimate-interests assessment for security/operations.
4. Verify the production OpenAI endpoint, `store` behaviour, organisation data controls, training opt-in status, DPA and UK transfer terms.
5. Verify ElevenLabs Zero Retention Mode entitlement and confirm eligible requests are absent from request history.
6. Verify Fly.io log retention, edge/client-IP handling, contractual entity, subprocessors and transfers.
7. Deploy and verify database retention cleanup.
8. Define and operate a verified server-side rights/deletion-request process, including identity matching and response ownership.
9. Decide and enforce a retention period for installation/security records and inactive beta installations.
10. Obtain legal review before describing the policy as legally approved.

## 12. Recommended policy posture

Until every production verification is complete, use narrow, factual wording:

- “may retain for up to 30 days under default controls,” not “stores for 30 days”;
- “our request asks ElevenLabs not to log,” not “ElevenLabs uses zero retention”;
- “clear local data,” not “delete all my data”;
- “we do not sell or use data for cross-app advertising,” if the final data flow still supports that claim;
- “exact coordinates are not sent to our proxy,” not “location never leaves the phone,” because Apple location and reverse-geocoding services are involved;
- “we do not upload rider-recorded audio,” not “we process no audio,” because generated speech audio is returned to the app.

This posture produces an accurate publishable policy without overstating controls that still require operational proof.

## Primary sources

- [Companies House: Digital Mercenaries Limited, company 05428486](https://find-and-update.company-information.service.gov.uk/company/05428486)
- [ICO: what privacy information should we provide?](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/the-right-to-be-informed/what-privacy-information-should-we-provide/)
- [ICO: a guide to lawful basis](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/a-guide-to-lawful-basis/)
- [ICO: international transfers](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/)
- [Data (Use and Access) Act 2025, section 77 explanatory notes](https://www.legislation.gov.uk/ukpga/2025/18/notes/division/10/index.htm)
- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: app privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple: manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [OpenAI: API data controls](https://developers.openai.com/api/docs/guides/your-data#default-usage-policies-by-endpoint)
- [OpenAI Data Processing Addendum](https://openai.com/en-GB/policies/data-processing-addendum/)
- [ElevenLabs: Zero Retention Mode](https://elevenlabs.io/docs/eleven-api/resources/zero-retention-mode)
- [ElevenLabs Data Processing Addendum](https://elevenlabs.io/dpa)

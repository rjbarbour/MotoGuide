# UK GDPR scope of RideHorizon operational data

Date: 2026-08-04

## Bottom line

The earlier advice was too categorical. Digital Mercenaries Limited does **not** have to treat every operational record as if it were readily identifiable customer data, nor must it surgically rewrite every backup after an erasure request.

The correct position is:

- genuinely anonymous information is outside the UK GDPR and Data Protection Act 2018 data-protection regime;
- an IP address, stable device identifier or hashed installation identifier may still be personal data even without a name, particularly when it singles out the same user or device;
- legitimate interests can support proportionate operational and security logging, but it is a lawful basis rather than an exemption from the UK GDPR;
- a subject access request requires a reasonable and proportionate search for personal data that can be related to the requester, not an unlimited forensic exercise;
- a valid erasure request normally requires deletion from live systems, but data in rotation-controlled backups can remain beyond use until it is overwritten under the documented retention schedule.

This is a practical compliance assessment, not legal advice.

## 1. Scope depends on identifiability, not the label “PII”

The UK statutory test is whether information relates to an identified or identifiable living individual. Identifiers expressly include identification numbers, location data and online identifiers. The same definition applies across the UK data-protection framework. [ICO: Introduction to anonymisation](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-sharing/anonymisation/introduction-to-anonymisation/)

The ICO says a controller does not need to know a person's name. A unique identifier used to single out a device or treat it differently can be personal data. IP addresses and other device identifiers *may* be personal data depending on context and the means reasonably likely to be used to identify or single out someone. [ICO: Indirect identification](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/personal-information-what-is-it/what-is-personal-data/can-we-identify-an-individual-indirectly/), [ICO: Identifiers and related factors](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/personal-information-what-is-it/what-is-personal-data/what-are-identifiers-and-related-factors/)

“Not linked” in Apple's App Privacy terminology is not the UK GDPR test. Likewise, “not PII” is not enough. The relevant distinctions are:

- **Anonymous:** no person is reasonably identifiable or capable of being singled out, considering the data and reasonably available additional information. UK data-protection law does not apply.
- **Pseudonymous:** direct identity has been replaced, but records still single out a person/device or can be attributed using additional information. It remains personal data.
- **Unidentified by name:** the controller does not know the real-world identity, but a persistent identifier may still make the user identifiable for UK GDPR purposes.

The possibility of identification need not be purely theoretical. The ICO requires a contextual assessment of means reasonably likely to be used and says a very slight hypothetical possibility is not enough. [ICO: Effective anonymisation](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-sharing/anonymisation/how-do-we-ensure-anonymisation-is-effective/)

## 2. Legitimate interests can justify ordinary operational logging

Legitimate interests is a plausible lawful basis for short-lived access, abuse-prevention, quota, reliability and security records. The ICO expressly recognises network and information security as a possible legitimate interest. The controller must still document the three-part test:

1. the specific legitimate purpose;
2. why the personal-data processing is necessary and proportionate for that purpose; and
3. why the person's interests, rights and freedoms do not override it.

It is not enough merely to state “legitimate interests”. Less intrusive alternatives, reasonable expectations, data minimisation and a defined retention period still matter. [ICO: Legitimate interests](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/legitimate-interests/what-is-the-legitimate-interests-basis/)

Therefore a properly minimised HTTP access log does not become unlawful just because it contains an IP address. It may be retained for a justified operational period. A request for erasure is not an automatic instruction to destroy every relevant security record: the right is not absolute, and where legitimate interests is the basis, erasure applies if the person objects and there is no overriding legitimate ground to continue. Data that is no longer necessary must not be retained merely because it might be useful later. [ICO: Right to erasure](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/individual-rights/right-to-erasure/), [ICO: Storage limitation](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-protection-principles/a-guide-to-the-data-protection-principles/storage-limitation/)

## 3. What a SAR realistically requires

A SAR concerns the requester's **personal data**, not every technical record associated with operating a service. The controller must make reasonable and proportionate efforts to find it. It can ask for information genuinely needed to locate the records, such as a relevant IP address, installation reference and narrow date/time range. It does not have to conduct an unreasonable or disproportionate search, but it should record why a search would cross that threshold. [ICO: Finding and retrieving information for a SAR](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/right-of-access/how-do-we-find-and-retrieve-the-relevant-information/)

If the processing purpose does not require real-world identification, Article 11 means the controller need not acquire or retain extra identifying data solely to comply with data-protection rights. The ICO expressly notes this principle. If the requester later supplies information that enables their records to be identified, the applicable rights must then be honoured. [ICO: Consent management and Article 11](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/consent/how-should-we-obtain-record-and-manage-consent/)

Practical consequence: a request containing only a person's name or email address does not require Digital Mercenaries to invent a link to anonymous or pseudonymous proxy records. It should explain that it does not hold an account/name mapping and invite the requester to provide a usable identifier or sufficiently precise technical details if they have them.

## 4. Backups do not normally need to be surgically rewritten

For access, the ICO says there is no blanket technology exemption for archived or backed-up personal data, but the search remains reasonable and proportionate. The controller should use the same level of effort it would use to retrieve the backup for its own purposes. It is not expected to use extreme measures to reconstruct data already deleted through normal records management. [ICO: Finding and retrieving information for a SAR](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/right-of-access/how-do-we-find-and-retrieve-the-relevant-information/)

For erasure, a valid request applies to live systems and backups, but the ICO expressly permits a practical model in which the live record is deleted and the backup copy remains **beyond use** until overwritten under an established schedule. The controller must not restore or use that copy for another purpose and must explain the backup treatment to the requester. [ICO: Right to erasure — backup systems](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/individual-rights/right-to-erasure/)

That is materially different from retrieving an offsite backup, editing an Apache log inside it and rebuilding the backup. A documented short rotation, access restriction and beyond-use rule is normally the proportionate approach.

## 5. Reassessment of RideHorizon

| RideHorizon record | Likely UK GDPR status for Digital Mercenaries | Practical rights treatment |
|---|---|---|
| Proxy application event containing only random request ID, method, route, status and duration, with no retained IP, installation ID, content or usable cross-reference | Likely anonymous/non-personal in Digital Mercenaries' hands, subject to confirmation that infrastructure data cannot reasonably link it back | No personal-data export or erasure is required if it genuinely cannot single out or be linked to a person. Retain under the operational log schedule. |
| Aggregate global usage counters without an individual key | Anonymous | Outside UK GDPR once genuinely anonymous. |
| Fly PostgreSQL quota/session rows keyed by `SHA-256("fallback:" + installation ID)` | Pseudonymous personal data: the persistent hash deliberately singles out one installation to apply quotas, even though no name is known | Covered by UK GDPR principles and retention controls. A name/email-only request cannot locate it. Article 11 means no extra identity system is required solely for rights requests. If the user can provide the installation identifier or another reliable lookup reference, respond to access/erasure as applicable. |
| Raw IP held briefly in the in-memory rate limiter | Potential personal data, but transient and automatically expired | Legitimate operational/security processing is plausible. It will normally have expired before a request can be processed; do not preserve it merely for a SAR. |
| Fly or Cloudflare edge/access records retaining IP plus timestamp/request metadata | Potential personal data in the relevant provider/controller context | Determine what is actually retained, under whose controllership, for how long, and what customer search/delete controls exist. Do not promise a per-user search where neither Digital Mercenaries nor its processor can reasonably locate the record. |
| OpenAI/ElevenLabs request content with no RideHorizon installation identifier | Context dependent. Generic place text may not relate to an identifiable person; unusual rider instructions, precise timing or a linkable sequence could do so | Do not assume all provider payloads are either personal or anonymous. Apply the identifiability test to the actual retained fields and available cross-references. Where no reliable association exists, Article 11 and proportionality are relevant; normal provider expiry remains appropriate. |
| Local iPhone data not transmitted to Digital Mercenaries | Not data held by Digital Mercenaries for a SAR | Explain that it remains under the user's control and can be cleared in the app or by deleting the app. |

## 6. Recommended operational position for the private beta

1. Keep the existing short automatic retention periods and data-minimised application logging.
2. Record a short legitimate-interests assessment for service security, abuse prevention, quotas and troubleshooting.
3. Verify which Fly and Cloudflare edge logs actually exist, their fields, retention and controller/processor status. This is a factual vendor-configuration check, not a reason to assume every edge event is RideHorizon customer data.
4. Handle rights requests by searching data that can reasonably be related to the requester. Ask for a technical identifier and date/time range where needed; do not collect identity merely to make anonymous records identifiable.
5. Delete applicable matched records from live systems when erasure is valid. Leave backup copies beyond use until normal snapshot expiry and disclose that schedule.
6. Do not add a user-facing privacy-request identifier solely because UK GDPR supposedly requires one. It may improve service and confidence, but Article 11 means it is not automatically necessary where identification is not part of the processing purpose.

## Correction to the previous note

The earlier statement that Digital Mercenaries would generally need to identify and erase matching records at every processor overstated the duty. Processor assistance is relevant only where personal data within the scope of a valid request can reasonably be identified and the right applies. Anonymous records are outside scope; unidentified pseudonymous records do not require the controller to acquire extra identifying data solely to satisfy the request; legitimate operational retention may lawfully continue; and rotation-controlled backups can remain beyond use until expiry.

# Milestone 5 Status

Date: 2026-07-08

## Result

Milestone 5 is functionally complete in the iOS app with **LLM-only** Short Facts and Long Facts. No curated JSON bundle is used.

Status update on 2026-07-03: proxy path works and prompt overrides improved isolated fact quality. A field-quality pass is still recommended on real rides, and the next quality gap is sequence repetition across nearby places.

Status update on 2026-07-03: on-device speech must default to proxy-backed Premium Voice during MVP. Existing installs may have an older persisted Apple voice provider, so iOS must migrate legacy Apple-provider defaults to Premium Voice unless the rider explicitly changes the provider after the migration. Long speech should be split into bounded `/v1/speech` requests and played sequentially, with Apple voice used only as an explicit fallback when proxy speech fails.

Status update on 2026-07-03: Premium Voice must not silently switch to Apple when proxy speech fails. The previous fallback behaviour made on-device speech sound inconsistent: some announcements used ElevenLabs and others used Apple. For MVP testing, a Premium Voice failure should log diagnostics and finish the speech item without speaking in Apple. Apple voices should only be used when the selected speech provider is Apple.

Status update on 2026-07-03: no proxy change is required for visible speech-fallback diagnostics. The iOS app owns speech routing and should show a test-mode-only note under the last spoken phrase when Premium Voice fails and Apple fallback is used for MVP continuity.

Status update on 2026-07-08: Apple fallback for Premium Voice is a developer feature flag, not a Test Mode default. The flag defaults off so ElevenLabs/proxy failures produce a visible error instead of masked Apple speech. When Test Mode is on, speech errors must appear on the main Location UI as well as the developer diagnostics log.

Status update on 2026-07-08: Speech/TTS uses a separate iOS timeout from facts. Facts remain `3 s`; `/v1/speech` uses `15 s` because Fly cold start plus ElevenLabs generation can exceed the previous shared `3 s` timeout. iOS diagnostics log speech elapsed time to completion / last byte.

Status update on 2026-07-08: the expanded Location bottom sheet must fit both the visible Premium Voice error and the current spoken/fact text. If content exceeds the expanded height, the panel must scroll instead of clipping.

Status update on 2026-07-27: removed the debug splash-time proxy token prompt from the iOS app, keeping automatic server-assisted session provisioning as the default path. The app now launches directly and can obtain proxy access via `/v1/session/fallback` without user token entry or invite UX.

## Approach

Facts are generated on demand through the RideHorizon fact proxy when the rider selects **Short Facts** or **Long Facts** announcement style and a speakable boundary change occurs.

The iOS app no longer needs an OpenAI API key. It calls the proxy; the proxy owns the OpenAI request and keeps the OpenAI key server-side.

OpenAPI contract source: `FACT_PROXY_OPENAPI.yaml`.

Human-readable companion: `docs/architecture/contracts/FACT_PROXY_CONTRACT.md`.

| Mode | LLM calls | Facts spoken |
|------|-----------|--------------|
| Natural | No | No |
| Names Only | No | No |
| Quiet | No | No |
| Short Facts | Yes, on boundary change only | Yes |
| Long Facts | Yes, on boundary change only | Yes |

## Architecture

| Module | Role |
|--------|------|
| `PlaceFactRequest` | Boundary type, place name, country context, cache key |
| `PlaceFactGenerating` | Protocol for fact providers |
| `ProxyFactGenerator` | Calls `POST /v1/fact` on the RideHorizon fact proxy |
| `KeychainCredentialLoader` | Loads the proxy token from Keychain service `RideHorizonProxy` and optional approved-device ID from `RideHorizonDeviceId` |
| `PlaceFactCache` | In-memory + UserDefaults cache by boundary + normalized place name |
| `CachedPlaceFactGenerator` | Cache wrapper around the proxy generator |
| `PlaceFactFetcher` | 3-second timeout; returns nil → name-only fallback |
| `FactPhraseBuilder` | Combines base phrase + fact; sanitizes output by selected fact mode |
| `LocationManager` | Async fact fetch after boundary detection; then Bluetooth-delay queue |

## Speech Provider Acceptance Criteria

- New installs default to Premium Voice backed by the proxy speech endpoint.
- Existing MVP installs with legacy Apple-provider storage migrate to Premium Voice on first launch after this fix.
- A rider can still select Apple voices in Settings after migration; that choice must persist.
- Announcements and preview use the same `LocationManager` speech provider path.
- Long speech is chunked into multiple `/v1/speech` requests before playback instead of being silently truncated.
- Speech requests use a separate `15 s` iOS timeout and log elapsed time to completion / last byte.
- If proxy speech fails while Premium Voice is selected, RideHorizon logs diagnostics and finishes the speech item without speaking in Apple by default.
- Apple voices are used only when the selected speech provider is `Apple voices`.
- Apple fallback for Premium Voice is controlled by a developer feature flag named `Allow Apple fallback for Premium Voice`; it defaults off.
- When Test Mode is on, Premium Voice errors must be shown on the main Location screen, not only inside Advanced / Developer diagnostics.

## Speech examples

- Town: `You are in Stonehouse, Gloucestershire`
- Region: `Welcome to Wales. You are in Chepstow, Monmouthshire`
- Country: `Welcome to France. You are in Calais, Pas-de-Calais`
- Short Facts target 35-45 words.
- Long Facts target 75-90 words.
- Current Short Facts and Long Facts append bounded LLM content after the base phrase according to the selected mode.

## Proxy API

This section is a summary. Keep `FACT_PROXY_OPENAPI.yaml` as the source of truth.

The default iOS endpoint is:

```text
https://ridehorizon.digitalmercenaries.ai/v1/fact
```

The app sends:

```http
Authorization: Bearer <RideHorizonProxy token>
Content-Type: application/json
```

Request body:

```json
{
  "boundary": "town",
  "placeName": "Stroud",
  "factMode": "shortFacts",
  "countryContext": "United Kingdom"
}
```

Response body:

```json
{
  "fact": "One short factual sentence."
}
```

Store the proxy token in the iOS Keychain generic-password item with service `RideHorizonProxy`. If device binding is enabled, store the approved-device identifier in the separate service `RideHorizonDeviceId`. Never store the OpenAI key in the app or repo.

If the proxy token is missing, the proxy errors, or the request times out after 3 seconds, RideHorizon speaks the base place announcement without the fact.

## Assumptions

- Network is available on rides where Short Facts or Long Facts is used.
- Cached facts persist for the session via UserDefaults to avoid repeat API calls at boundary jitter.
- The proxy is the sole fact source for MVP; no bundled offline facts.
- Riders are adults, probably middle-aged touring motorcyclists. Facts should not sound like a children's encyclopaedia or explain obvious UK context.
- Optional home/familiar-region context should be coarse, such as country/region, not an exact home address.

## Quality Pass Required

Update the proxy contract and implementation before broader testing:

- Short Facts: 35-45 words, one sentence or two short sentences.
- Long Facts: 75-90 words, two to four concise sentences; still safe, interruptible, and non-instructional.
- Prompt style: specific, locally meaningful, and adult-level. Avoid banal administrative definitions.
- Home/familiar context: allow iOS to send coarse context such as `homeCountry`, `homeRegion`, or `familiarRegions` so the proxy can avoid obvious explanations.
- Ride sequence context: add optional previous spoken places, previous topics, avoid topics, desired novelty, and familiarity policy.
- Topic memory: keep the last 3-5 spoken fact topics so nearby towns do not repeat the same Cotswolds/limestone/stone/wool/cloth/mills setup.
- Home quiet radius: add a post-field-trial setting for Off, 5 miles, 10 miles, or 25 miles. Inside that radius, prefer silence or names-only unless the rider explicitly asks for facts.
- Tests: add route-place fixtures and assertions for length, mode selection, sanitization, no prompt leakage, no raw coordinates, no schoolbook definitions, and low sequence repetition.

## Fact Quality Review References

- Raw generation log: `docs/evidence/fact-quality/FACT_QUALITY_REVIEW_2026-07-03.md`
- Sequence review: `docs/evidence/fact-quality/FACT_SEQUENCE_QUALITY_REVIEW_2026-07-03.md`
- Current prompt override example: `prompt-overrides/fact-quality-2026-07-03.json`

## Tests

Unit tests use `MockPlaceFactGenerator` and `MockURLProtocol` — no real network in XCTest.

**Result (2026-07-01):** `PlaceFactTests` — **TEST SUCCEEDED** on iPhone 17 simulator (iOS 26.3.1). Coverage includes phrase building, cache, timeout, short-facts and long-facts announcement integration, proxy request shape, bearer token handling, and proxy HTTP errors.

## Deploy

Build and install on Robert's iPhone per `AGENTS.md`. Simulator unit tests run at milestones, not every edit.

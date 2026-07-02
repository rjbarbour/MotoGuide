# Milestone 5 Status

Date: 2026-07-02

## Result

Milestone 5 is functionally complete in the iOS app with **LLM-only** Short Facts and Long Facts. No curated JSON bundle is used.

Status update on 2026-07-02: proxy path works and fact quality settings were updated (short facts and long facts bounds/prompts). A field-quality pass is still recommended on real rides.

## Approach

Facts are generated on demand through the MotoGuide fact proxy when the rider selects **Short Facts** or **Long Facts** announcement style and a speakable boundary change occurs.

The iOS app no longer needs an OpenAI API key. It calls the proxy; the proxy owns the OpenAI request and keeps the OpenAI key server-side.

OpenAPI contract source: `FACT_PROXY_OPENAPI.yaml`.

Human-readable companion: `FACT_PROXY_CONTRACT.md`.

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
| `ProxyFactGenerator` | Calls `POST /v1/fact` on the MotoGuide fact proxy |
| `KeychainCredentialLoader` | Loads the proxy token from Keychain service `MotoGuideProxy` and optional approved-device ID from `MotoGuideDeviceId` |
| `PlaceFactCache` | In-memory + UserDefaults cache by boundary + normalized place name |
| `CachedPlaceFactGenerator` | Cache wrapper around the proxy generator |
| `PlaceFactFetcher` | 3-second timeout; returns nil → name-only fallback |
| `FactPhraseBuilder` | Combines base phrase + fact; sanitizes output by selected fact mode |
| `LocationManager` | Async fact fetch after boundary detection; then Bluetooth-delay queue |

## Speech examples

- Town: `You are in Stonehouse, Gloucestershire`
- Region: `Welcome to Wales. You are in Chepstow, Monmouthshire`
- Country: `Welcome to France. You are in Calais, Pas-de-Calais`
- Short Facts now use the 1100-character bound and up to 5 concise sentences.
- Long Facts now use the 1500-character bound and up to 8 concise sentences.
- Current Short Facts and Long Facts append bounded LLM content after the base phrase according to the selected mode.

## Proxy API

This section is a summary. Keep `FACT_PROXY_OPENAPI.yaml` as the source of truth.

The default iOS endpoint is:

```text
https://motoguide-fact-proxy.fly.dev/v1/fact
```

The app sends:

```http
Authorization: Bearer <MotoGuideProxy token>
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

Store the proxy token in the iOS Keychain generic-password item with service `MotoGuideProxy`. If device binding is enabled, store the approved-device identifier in the separate service `MotoGuideDeviceId`. Never store the OpenAI key in the app or repo.

If the proxy token is missing, the proxy errors, or the request times out after 3 seconds, MotoGuide speaks the base place announcement without the fact.

## Assumptions

- Network is available on rides where Short Facts or Long Facts is used.
- Cached facts persist for the session via UserDefaults to avoid repeat API calls at boundary jitter.
- The proxy is the sole fact source for MVP; no bundled offline facts.
- Riders are adults, probably middle-aged touring motorcyclists. Facts should not sound like a children's encyclopaedia or explain obvious UK context.
- Optional home/familiar-region context should be coarse, such as country/region, not an exact home address.

## Quality Pass Required

Update the proxy contract and implementation before broader testing:

- Short Facts: up to 5 concise sentences, up to 1100 characters.
- Long Facts: up to 8 concise sentences, up to 1500 characters; still safe, interruptible, and non-instructional.
- Prompt style: specific, locally meaningful, and adult-level. Avoid banal administrative definitions.
- Home/familiar context: allow iOS to send coarse context such as `homeCountry`, `homeRegion`, or `familiarRegions` so the proxy can avoid obvious explanations.
- Tests: add route-place fixtures and assertions for length, mode selection, sanitization, no prompt leakage, no raw coordinates, and no schoolbook definitions.

## Tests

Unit tests use `MockPlaceFactGenerator` and `MockURLProtocol` — no real network in XCTest.

**Result (2026-07-01):** `PlaceFactTests` — **TEST SUCCEEDED** on iPhone 17 simulator (iOS 26.3.1). Coverage includes phrase building, cache, timeout, short-facts and long-facts announcement integration, proxy request shape, bearer token handling, and proxy HTTP errors.

## Deploy

Build and install on Robert's iPhone per `AGENTS.md`. Simulator unit tests run at milestones, not every edit.

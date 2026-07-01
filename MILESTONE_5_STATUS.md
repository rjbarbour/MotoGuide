# Milestone 5 Status

Date: 2026-07-01

## Result

Milestone 5 is complete with **LLM-only** short facts. No curated JSON bundle is used.

## Approach

Facts are generated on demand through the MotoGuide fact proxy when the rider selects **Short Facts** announcement style and a speakable boundary change occurs.

The iOS app no longer needs an OpenAI API key. It calls the proxy; the proxy owns the OpenAI request and keeps the OpenAI key server-side.

OpenAPI contract source: `FACT_PROXY_OPENAPI.yaml`.

Human-readable companion: `FACT_PROXY_CONTRACT.md`.

| Mode | LLM calls | Facts spoken |
|------|-----------|--------------|
| Natural | No | No |
| Names Only | No | No |
| Quiet | No | No |
| Short Facts | Yes, on boundary change only | Yes |

## Architecture

| Module | Role |
|--------|------|
| `PlaceFactRequest` | Boundary type, place name, country context, cache key |
| `PlaceFactGenerating` | Protocol for fact providers |
| `ProxyFactGenerator` | Calls `POST /v1/fact` on the MotoGuide fact proxy |
| `KeychainCredentialLoader` | Loads the proxy token from Keychain service `MotoGuideProxy` |
| `PlaceFactCache` | In-memory + UserDefaults cache by boundary + normalized place name |
| `CachedPlaceFactGenerator` | Cache wrapper around the proxy generator |
| `PlaceFactFetcher` | 3-second timeout; returns nil → name-only fallback |
| `FactPhraseBuilder` | Combines base phrase + fact; sanitizes output (max 120 chars) |
| `LocationManager` | Async fact fetch after boundary detection; then Bluetooth-delay queue |

## Speech examples

- Town: `You are in Stonehouse, Gloucestershire`
- Nation: `Welcome to Wales. You are in Chepstow, Monmouthshire`
- Country: `Welcome to France. You are in Calais, Pas-de-Calais`
- Short facts append one LLM sentence after the base phrase

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
  "countryContext": "United Kingdom"
}
```

Response body:

```json
{
  "fact": "One short factual sentence."
}
```

Store only the proxy token in the iOS Keychain generic-password item with service `MotoGuideProxy`. Never store the OpenAI key in the app or repo.

If the proxy token is missing, the proxy errors, or the request times out after 3 seconds, MotoGuide speaks the **name-only** announcement.

## Assumptions

- Network is available on rides where Short Facts is used.
- Cached facts persist for the session via UserDefaults to avoid repeat API calls at boundary jitter.
- The proxy is the sole fact source for MVP; no bundled offline facts.

## Tests

Unit tests use `MockPlaceFactGenerator` and `MockURLProtocol` — no real network in XCTest.

**Result (2026-07-01):** `PlaceFactTests` — **TEST SUCCEEDED** on iPhone 17 simulator (iOS 26.3.1). Coverage includes phrase building, cache, timeout, short-facts announcement integration, proxy request shape, bearer token handling, and proxy HTTP errors.

## Deploy

Build and install on Robert's iPhone per `AGENTS.md`. Simulator unit tests run at milestones, not every edit.

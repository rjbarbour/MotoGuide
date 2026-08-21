# RideHorizon Fact Proxy Contract

Date: 2026-07-31

Last reconciled: 2026-08-21

Status: Human-readable companion to `FACT_PROXY_OPENAPI.yaml`.

Source of truth: `FACT_PROXY_OPENAPI.yaml`.

Keep the iOS app, fact proxy server, tests, and markdown in sync with the OpenAPI specification.

## Purpose

The fact proxy contract lets RideHorizon ask for one bounded place fact without storing or sending an OpenAI API key from the iOS app.

The iOS app sends `factMode`, the boundary/place fields, and the current place hierarchy to the RideHorizon fact proxy. It also sends optional rider context (`homeCountry`, `homeRegion`, `familiarRegions`, `customFactInstructions`) and optional `factInterestCategories` so the proxy can tune fact focus toward geography, culture, history, landmarks, and practical rider context without sending prompts.

Speech is proxied separately through ElevenLabs. The iOS app sends bounded text to `/v1/speech`; the proxy owns the ElevenLabs API key, voice id, model id, and output format.
The proxy validates the request, chooses the server-side prompt for `shortFacts` or `longFacts`, calls OpenAI server-side, sanitizes the model output, and returns a bounded fact.

The iOS app must not send prompt text, arbitrary model messages, OpenAI configuration, raw coordinates, or an OpenAI API key.

For an active ride, the app owns one bounded Responses API chain. It sends the
app-owned ride UUID and latest successful `previous_response_id` as bounded
headers, then replaces its local link with the response ID returned by the
proxy. The proxy keeps no process-local conversation state. End ride and
terminal fact failures discard the app link, and active-ride requests bypass
the persisted cross-ride fact cache so every delivered fact advances the
current chain.

The proxy uses `store=true` for this linkage. OpenAI currently documents that
Responses API application state is retained for at least 30 days in this
configuration. End ride stops further linkage but does not remotely delete
provider application state.

Every place-fact Responses request offers the hosted `web_search` tool without
forcing its use. OpenAI's model may make zero or one search call; the proxy sets
`max_tool_calls: 1` to bound the dominant per-fact tool cost. A derived search
query may contain the minimised place and rider-preference context already sent
to OpenAI. The proxy does not request sources, return search metadata to the
app, or log search queries, results, sources, place text, or rider text. It
counts only `web_search_call` output items for privacy-safe cost diagnostics.

Responses may contain reasoning and hosted-tool output items before the final
message. The proxy ignores those items as rider text and extracts only
`output_text` from final message content. It accepts either a completed
unsearched response or a completed one-search response, then applies the
existing sanitizer. A failed search, more than one search call, provider
failure, timeout, incomplete response, missing final text, or rejected text
remains a `502`; the iOS client retains its bounded retries and base-place
announcement fallback.

## Implementations

- iOS client: `RideHorizon/ProxyFactGenerator.swift`
- iOS token loader: `RideHorizon/KeychainCredentialLoader.swift`
- iOS tests: `RideHorizonTests/PlaceFactTests.swift`, `ProxyFactGeneratorTests`
- Proxy endpoint: `fact-proxy/src/main/java/ai/dml/ridehorizon/factproxy/FactController.java`
- Proxy request model: `fact-proxy/src/main/java/ai/dml/ridehorizon/factproxy/FactRequest.java`
- Proxy response model: `fact-proxy/src/main/java/ai/dml/ridehorizon/factproxy/FactResponse.java`
- Proxy docs: `fact-proxy/README.md`
- OpenAPI spec: `FACT_PROXY_OPENAPI.yaml`

## Validate The OpenAPI Spec

Exact command:

```bash
./fact-proxy/gradlew -p fact-proxy openApiContractTest --no-daemon
```

Expected result: `BUILD SUCCESSFUL`. The gate validates OpenAPI `3.0.3`, contract version `0.2.0`, every published operation, schema and security scheme, and proves the intentional version-drift fixture fails validation.

Drift proof:

```bash
./fact-proxy/gradlew -p fact-proxy openApiContractTest --no-daemon -PopenApiContract=src/test/resources/contracts/openapi/version-drift.yaml
```

Expected result: `BUILD FAILED`; the `configuredContractIsValidAndComplete` test report identifies the `info.version` drift.

## Shared Contract Fixtures

Canonical privacy-safe examples live under `fixtures/contracts/app-proxy/v1/`:

- `fact-request.json` — fact-request encoder/decoder contract;
- `fact-response.json` — successful fact response; and
- `speech-error-response.json` — coded Premium Voice error response.

Swift and Java tests consume these same files. Validate the Java consumers with:

```bash
./fact-proxy/gradlew -p fact-proxy sharedContractFixtureTest --no-daemon
```

Expected result: `BUILD SUCCESSFUL`.

## Endpoint

Production endpoint:

```text
https://ridehorizon.digitalmercenaries.ai/v1/fact
```

Local endpoint:

```text
http://127.0.0.1:3000/v1/fact
```

## Current Fly Deployment

Date verified: 2026-07-01.

| Field | Value |
|-------|-------|
| Fly app | `ridehorizon-fact-proxy` |
| Fly org | `dml` |
| Hostname | `ridehorizon.digitalmercenaries.ai` |
| Primary region | `lhr` |
| Image | `ridehorizon-fact-proxy:deployment-01KWFY4N628G4137Y7BMQPN6P9` |
| Shared IPv4 | `66.241.125.198` |
| Dedicated IPv6 | `2a09:8280:1::13b:6469:0` |

Current machines:

| Machine ID | Process | Region | Version | State |
|------------|---------|--------|---------|-------|
| `080d306c727d98` | `app` | `lhr` | `6` | `started` |
| `8ee01dc77de778` | `app` | `lhr` | `6` | `started` |

Required Fly secrets:

| Secret | Status |
|--------|--------|
| `OPENAI_API_KEY` | Deployed |
| `RIDEHORIZON_PROXY_TOKEN` | Deployed |
| `RIDEHORIZON_ADMIN_TOKEN` | Optional; enables admin diagnostics endpoint when deployed |

Runtime configuration:

| Environment variable | Default | Meaning |
|----------------------|---------|---------|
| `OPENAI_MODEL` | Live: `gpt-4o-mini`; RH-062 candidate: `gpt-5.6-sol` | OpenAI model selected by the Fly runtime environment. The candidate has not yet been deployed; merging it to `main` intentionally deploys it for private-beta evaluation. |
| `RIDEHORIZON_DIAGNOSTICS_ENABLED` | `false` | Enables verbose proxy diagnostics at startup. |
| `RIDEHORIZON_SHORT_FACT_PROMPT` | Built-in prompt | Optional server-side prompt override for `shortFacts`. Never sent by iOS. |
| `RIDEHORIZON_LONG_FACT_PROMPT` | Built-in prompt | Optional server-side prompt override for `longFacts`. Never sent by iOS. |
| `RIDEHORIZON_PROMPT_OVERRIDES_ENABLED` | `false` | When `true`, load prompt overrides from object storage. |
| `RIDEHORIZON_PROMPT_OVERRIDES_OBJECT_URL` | (not set) | Optional URL for prompt override JSON. |
| `RIDEHORIZON_PROMPT_OVERRIDES_REFRESH_SECONDS` | `60` | Poll interval for override updates from object storage. |
| `RIDEHORIZON_PROMPT_OVERRIDES_AUTH_TOKEN` | (not set) | Optional bearer token for override object download. |
| `RIDEHORIZON_PROMPT_OVERRIDES_HOST_ALLOWLIST` | (not set) | Comma-separated host allowlist. Required when `RIDEHORIZON_PROMPT_OVERRIDES_ENABLED=true`. |
| `RATE_LIMIT_PER_MINUTE` | `30` | Per identity (trusted user/device if provided, else IP) request limit for authenticated proxy calls. |

### RH-028 candidate OpenAI request contract

The review candidate calls `POST /v1/responses` with `gpt-5.6-sol`, `reasoning.effort: medium`, the model-controlled hosted `web_search` tool and `max_tool_calls: 1`. It retains `store: false` outside rides and RH-063's `store: true`, `previous_response_id` and compaction behaviour for active rides. It sets `max_output_tokens: 4096`, a product-selected ceiling for tightly bounded 35–90-word facts. The proxy accepts only a top-level Responses result with `status: completed`, tolerates reasoning and hosted-tool output items, extracts only typed final-message `output_text`, and applies the existing fact sentence and character limits. [OpenAI tools guidance](https://developers.openai.com/api/docs/guides/tools) [OpenAI Responses reference](https://developers.openai.com/api/reference/resources/responses/methods/create) [OpenAI reasoning guidance](https://developers.openai.com/api/docs/guides/reasoning#allocating-space-for-reasoning) [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data#v1responses)

This is candidate behaviour only. RH-028 is not merged or deployed by this work item hand-off.

Health check:

```bash
curl -fsS https://ridehorizon.digitalmercenaries.ai/health
```

Expected result:

```text
ok
```

If local DNS is still propagating, this equivalent command verifies the Fly public route through the assigned shared IPv4:

```bash
curl -fsS --resolve ridehorizon.digitalmercenaries.ai:443:66.241.125.198 https://ridehorizon.digitalmercenaries.ai/health
```

Expected result:

```text
ok
```

## Authentication

The iOS app automatically requests a restricted session from `POST /v1/session/fallback`. It sends a random per-install identifier in `X-RideHorizon-Device-Id`, stores both that identifier and the short-lived returned session token in Keychain, and renews the session after expiry or a `401`. Testers never enter or see a token.

Every `POST /v1/fact` and `POST /v1/speech` request must include:

```http
Authorization: Bearer <SHORT_LIVED_SESSION_TOKEN>
Content-Type: application/json
```

Optional request header for prompt overrides:

```http
X-RideHorizon-User-Id: rider-42
```

Per-install request header:

```http
X-RideHorizon-Device-Id: <RANDOM_PER_INSTALL_IDENTIFIER>
```

The iOS app reads the session token from the iOS Keychain generic-password item with service:

```text
RideHorizonProxy
```

The iOS app reads the per-install identifier from a separate iOS Keychain generic-password item with service:

```text
RideHorizonDeviceId
```

If that item is absent, iOS securely generates and stores one before requesting a session.

The OpenAI API key must stay server-side. It must be configured only on the proxy host, for example as the Fly.io secret `OPENAI_API_KEY`.

Current MVP security model:

- Transport is HTTPS through Fly.io public ingress.
- App authentication uses automatic short-lived restricted bearer sessions.
- The app stores only the short-lived session token and a random per-install identifier, not provider API keys.
- The OpenAI key is stored only as the Fly secret `OPENAI_API_KEY`.
- The ElevenLabs key is stored only as the Fly secret `ELEVENLABS_API_KEY`.
- The proxy only exposes a narrow place-fact endpoint; clients cannot send arbitrary OpenAI prompts, model names, endpoints, or message arrays.
- The proxy validates `boundary`, `factMode`, `placeName`, `countryContext`, `placeHierarchy`, and optional `riderContext`.
- The proxy applies per-install daily limits, global daily limits, and per-IP session-issuance limits.

Current limitation:

- Automatic restricted sessions are not yet backed by Apple App Attest, so a modified client could request sessions until server limits apply.

Planned hardening:

- Apple App Attest assertion verification.
- Server-side approved-device state with revoke/block support.
- Per-device and per-user quotas.
- Per-user authentication before wider non-TestFlight distribution.

Prompt override configuration (server-side only):

- If `RIDEHORIZON_PROMPT_OVERRIDES_ENABLED=true`, the proxy resolves prompt overrides in this order:
  1. `users` (by `X-RideHorizon-User-Id` header)
  2. `hierarchies` map keyed by `<boundary>:<normalized name>`
  3. `boundaries` map by boundary (`town`, `county`, etc.)
  4. `modePrompts`
  5. environment variables `RIDEHORIZON_SHORT_FACT_PROMPT` and `RIDEHORIZON_LONG_FACT_PROMPT`

Example object payload:

```json
{
  "modePrompts": {
    "shortFacts": "up to five concise local-context facts, up to 1100 characters",
    "longFacts": "up to eight concise contextual facts, up to 1500 characters total"
  },
  "users": {
    "rider-a": {
      "shortFacts": "brief UK-focused historical context"
    }
  },
  "boundaries": {
    "town": {
      "shortFacts": "focus on why the town is worth mentioning"
    }
  },
  "hierarchies": {
    "country:united kingdom": {
      "shortFacts": "use UK-specific phrasing when possible"
    }
  }
}
```

This requires no app contract changes.

## Observability

The proxy returns an `X-Request-Id` header on `/v1/fact` responses.

The app may send its own safe `X-Request-Id` header using only letters, digits, `.`, `_`, `:`, or `-`, between 8 and 80 characters. If it does not, the proxy generates a UUID.

Proxy logs include these event names:

| Event | Meaning | Sensitive fields logged |
|-------|---------|-------------------------|
| `fact_proxy_request` | Final request status and duration for `/v1/fact`. | No token, no place name, no IP. |
| `fact_request_valid` | Request passed deterministic validation. Emitted only when diagnostics are enabled. | Boundary, fact mode, place-name length, country-context presence. |
| `fact_request_success` | Fact generated and returned. Emitted only when diagnostics are enabled. | Boundary, fact mode, fact length. |
| `fact_request_rejected` | Request failed validation with `400`. | Rejection reason only. |
| `proxy_auth_failed` | Missing or wrong bearer token with `401`. | Failure category only. |
| `proxy_auth_misconfigured` | Missing server-side proxy token with `500`. | No secret value. |
| `rate_limit_exceeded` | Client exceeded per-IP limit with `429`. | Limit value only. |
| `openai_response` | OpenAI returned an HTTP response. Emitted only when diagnostics are enabled. | Status, duration, boundary. |
| `openai_upstream_error` | OpenAI returned an unusable response. | Boundary and bounded reason. |
| `openai_request_failed` | OpenAI request failed before usable response. | Boundary and exception class. |
| `diagnostics_updated` | Admin diagnostics setting changed for the current proxy process. | Enabled flag only. |
| `prompt_overrides_loaded` | Prompt override configuration was loaded from object storage. | Source URL only. |
| `prompt_overrides_load_failed` | Prompt override configuration failed to load; prior override state retained. | Failure reason only. |
| `prompt_overrides_load_skipped` | Prompt override loading skipped because object URL is not set. | Reason only. |

Diagnostics control:

- Baseline request logs remain on so app-reported `X-Request-Id` values can be matched to Fly logs.
- Verbose diagnostics are off by default.
- Set `RIDEHORIZON_DIAGNOSTICS_ENABLED=true` to enable verbose diagnostics at process startup.
- `GET /admin/diagnostics` returns the current setting when `RIDEHORIZON_ADMIN_TOKEN` is configured.
- `PUT /admin/diagnostics` with `{"enabled": true}` or `{"enabled": false}` changes the setting for the current running proxy process.
- The admin endpoint requires `Authorization: Bearer <RIDEHORIZON_ADMIN_TOKEN>`.
- If `RIDEHORIZON_ADMIN_TOKEN` is not configured, `/admin/diagnostics` returns `404`.
- Runtime changes are process-local. On a multi-machine Fly deployment, prefer the environment variable for a consistent fleet-wide setting.

Live debugging command:

```bash
cd /Users/rob_dev/DocsLocal/motoguide/repo/fact-proxy
fly logs
```

Expected result: live Fly logs showing the event names above. No bearer tokens, OpenAI keys, exact place names, or rider coordinates should appear in logs.

## Request

Method:

```http
POST /v1/fact
```

Optional header:

```http
X-RideHorizon-User-Id: <stable rider identifier>
```

JSON body:

```json
{
  "boundary": "town",
  "placeName": "Stroud",
  "factMode": "shortFacts",
  "countryContext": "United Kingdom",
  "placeHierarchy": {
    "town": "Stroud",
    "county": "Gloucestershire",
    "region": "England",
    "country": "United Kingdom"
  },
"riderContext": {
  "homeCountry": "United Kingdom",
  "homeRegion": "West Midlands",
  "familiarRegions": ["England", "Cotswolds"],
  "factInterestCategories": [
    "geographyBasics",
    "locationFacts",
    "pointsOfInterest",
    "history"
  ],
  "customFactInstructions": "engineering and old roads"
}
}
```

Fields:

| Field | Required | Type | Allowed values | Meaning |
|-------|----------|------|----------------|---------|
| `boundary` | Yes | String | `country`, `nation`, `county`, `town`, `street` | The boundary type that triggered the announcement. |
| `placeName` | Yes | String | Non-empty place name | The place to generate a fact about. |
| `factMode` | Yes | String | `shortFacts`, `longFacts` | Requested fact depth. The proxy owns prompt selection and rejects unknown values with `400`. |
| `countryContext` | No | String or `null` | Non-empty country name when known | Disambiguates places with reused names. |
| `placeHierarchy` | Yes | Object | `street`, `town`, `county`, `region`, `country` string values or omitted/null | Current reverse-geocoded hierarchy. Coordinates are not sent. |
| `riderContext` | No | Object | `homeCountry`, `homeRegion`, `familiarRegions`, `factInterestCategories`, `customFactInstructions` | Optional rider context to avoid obvious geography and tune fact focus by selected themes. |

The iOS app must map `BoundaryType.factLabel` directly to `boundary`.

The iOS app maps content modes to fact modes as follows:

| iOS content mode | Proxy call |
|------------------|------------|
| `Short Facts` | `factMode: "shortFacts"` |
| `Long Facts` | `factMode: "longFacts"` |
| `Natural` | No proxy call |
| `Names Only` | No proxy call |
| `Quiet` | No proxy call |

Input hardening:

- `placeName` is trimmed and whitespace-normalized before prompting.
- `placeName` maximum length is 96 characters.
- `countryContext` maximum length is 64 characters.
- `placeHierarchy` values use the same bounded validation as `placeName` and `countryContext`.
- Inputs must contain at least one Latin letter.
- Inputs must use only Latin letters, digits where useful, spaces, and common UK place-name punctuation: `.`, `,`, `'`, `’`, `&`, `(`, `)`, `-`.
- `countryContext` is stricter and does not allow digits or `&`.
- `riderContext.customFactInstructions` is optional, capped at 240 characters, and treated as untrusted rider preference data rather than model/system prompt text.
- `riderContext.factInterestCategories` is optional. Accepted values are:
  - `localRidingHints`
  - `safetyAdvice` (legacy alias, still accepted for backwards compatibility)
  - `geographyBasics`
  - `locationFacts`
  - `pointsOfInterest`
  - `history`
  - `culture`
  - `landmarks`
  Up to 7 entries are allowed.
- `riderContext.customFactInstructions` must not contain control language such as `system`, `ignore`, `return`, `json`, `script`, or `tool`.
- Inputs with more than 10 whitespace-separated words are rejected.
- Inputs with repeated suspicious punctuation are rejected.
- Obvious prompt-injection terms such as `ignore`, `system`, `developer`, `prompt`, `instruction`, `json`, `return`, `output`, `script`, and `tool` are rejected.
- Rejected inputs return `400` and must not call OpenAI.

## Response

Success response:

```http
200 OK
Content-Type: application/json
```

JSON body:

```json
{
  "fact": "Known for its wool trade."
}
```

Fields:

| Field | Required | Type | Meaning |
|-------|----------|------|---------|
| `fact` | Yes | String | One bounded, factual, ride-safe fact. `shortFacts` is capped at 1100 characters. `longFacts` is capped at 1500 characters. |

## Error Responses

| Status | Meaning | iOS behavior |
|--------|---------|--------------|
| `400` | Invalid JSON, missing required field, invalid `boundary`, invalid `factMode`, invalid `placeName`, or invalid `placeHierarchy`. | Fall back to the base place announcement. |
| `401` | Missing or wrong proxy token. | Fall back to the base place announcement. |
| `500` | Proxy is misconfigured, including missing server-side proxy token. | Fall back to the base place announcement. |
| `502` | OpenAI returned an error or unusable response. | Retry while the transient-retry budget remains, then fall back to the base place announcement. |

The iOS app must not speak raw error text.

## Speech Request

Endpoint:

```http
POST /v1/speech
Authorization: Bearer <RIDEHORIZON_PROXY_TOKEN>
Content-Type: application/json
Accept: audio/mpeg
```

JSON body:

```json
{
  "text": "Stroud was known for its wool trade."
}
```

Fields:

| Field | Required | Type | Allowed values | Meaning |
|-------|----------|------|----------------|---------|
| `text` | Yes | String | 1 to 1400 characters | Rider-facing text to synthesize. |

Success response:

```http
200 OK
Content-Type: audio/mpeg
```

Provider failure response:

```http
502 Bad Gateway
Content-Type: application/json
```

```json
{
  "error": "Premium voice is temporarily unavailable.",
  "code": "RH-TTS-02"
}
```

The message is deliberately neutral. The proxy must never return the raw ElevenLabs response body or expose account, credit, quota, authentication, or billing details to the app.

Diagnostic codes:

| Code | Operator meaning | Rider-facing treatment |
|------|------------------|------------------------|
| `RH-TTS-01` | Provider authentication or server configuration | Show only the neutral message and code in Test Mode diagnostics. |
| `RH-TTS-02` | Provider account capacity | Show only the neutral message and code in Test Mode diagnostics. |
| `RH-TTS-03` | Provider throttling | Show only the neutral message and code in Test Mode diagnostics. |
| `RH-TTS-04` | Other provider or transport failure | Show only the neutral message and code in Test Mode diagnostics. |

The proxy calls ElevenLabs server-side using environment configuration:

| Variable | Required | Meaning |
|----------|----------|---------|
| `ELEVENLABS_API_KEY` | Yes for `/v1/speech` | ElevenLabs API key. Server-side only. |
| `ELEVENLABS_VOICE_ID` | No | Voice id. Defaults to the configured service default. |
| `ELEVENLABS_MODEL_ID` | No | Model id. Defaults to `eleven_multilingual_v2`. |
| `ELEVENLABS_OUTPUT_FORMAT` | No | Output format. Defaults to `mp3_44100_128`. |

The iOS app treats `/v1/speech` separately from fact generation:

- Speech attempt timeout: `35 s`.
- Fact attempt timeout: `35 s`.
- Complete fact or Premium Voice operation timeout: `60 s`, including transient retries.
- Automatic session attempt timeout: `12 s`; complete session-provisioning timeout: `30 s`.
- Retry delays: `3 s`, then `10 s`, while the operation budget remains.
- Retry transient connection errors and HTTP `408`, `502`, `503`, and `504`; do not retry ordinary `4xx` failures.
- A structured Premium Voice HTTP `502` retries only diagnostic code `RH-TTS-04`, not authentication, account-capacity, or throttling codes.
- Speech diagnostics should log request elapsed time to completion / last byte.
- Apple speech fallback is feature-flagged during the private beta and defaults on so ride-facing speech remains available during provider outages; when the rider turns fallback off, errors are visible in Test Mode instead of silently speaking Apple.

## Speech Safety Rules

The returned `fact` must be:

- `shortFacts`: up to 5 short sentences and no more than 1100 characters.
- `longFacts`: up to 8 short sentences and no more than 1500 characters.
- Factual and neutral.
- Useful as ambient place context.
- Short enough to keep the total spoken announcement ride-safe.
- Free of questions.
- Free of invitations, route advice, speed advice, or riding instructions.

The current iOS sanitizer rejects empty facts, questions, and `you should` phrasing, and truncates facts using the selected fact mode.

## Timeout And Fallback

The iOS app gives each fact attempt up to 35 seconds and bounds the complete fact operation to 60 seconds through `PlaceFactFetcher`. A newer boundary announcement cancels the older request and its retry backoff.

If the proxy token is missing, all allowed attempts fail, the proxy returns a permanent error, response JSON is invalid, the fact is rejected by the sanitizer, or the operation deadline expires, RideHorizon must speak the base place announcement without a fact. A superseded request must not speak a delayed result or trigger Apple fallback.

Example fallback:

```text
You are in Stroud, Gloucestershire
```

## Example Curl

Exact command:

```bash
curl -sS -X POST http://127.0.0.1:3000/v1/fact \
  -H "Authorization: Bearer dev-token" \
  -H "Content-Type: application/json" \
  -d '{"boundary":"town","placeName":"Stroud","factMode":"shortFacts","countryContext":"United Kingdom","placeHierarchy":{"town":"Stroud","county":"Gloucestershire","region":"England","country":"United Kingdom"},"riderContext":{"homeCountry":"United Kingdom","homeRegion":"West Midlands","familiarRegions":["England","Cotswolds"],"customFactInstructions":"engineering and old roads"}}'
```

Expected result:

```json
{
  "fact": "One bounded factual sentence."
}
```

Exact command:

```bash
curl -sS -X POST http://127.0.0.1:3000/v1/speech \
  -H "Authorization: Bearer dev-token" \
  -H "Content-Type: application/json" \
  -o /tmp/ridehorizon-speech.mp3 \
  -d '{"text":"Stroud was known for its wool trade."}'
```

Expected result:

```text
/tmp/ridehorizon-speech.mp3 exists and contains MP3 audio.
```

The exact fact sentence can vary because it is generated by the server-side LLM.

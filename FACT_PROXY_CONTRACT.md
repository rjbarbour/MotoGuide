# MotoGuide Fact Proxy Contract

Date: 2026-07-01

Status: Human-readable companion to `FACT_PROXY_OPENAPI.yaml`.

Source of truth: `FACT_PROXY_OPENAPI.yaml`.

Keep the iOS app, fact proxy server, tests, and markdown in sync with the OpenAPI specification.

## Purpose

The fact proxy contract lets MotoGuide ask for one bounded place fact without storing or sending an OpenAI API key from the iOS app.

The iOS app sends `factMode`, the boundary/place fields, and the current place hierarchy to the MotoGuide fact proxy. The proxy validates the request, chooses the server-side prompt for `shortFacts` or `longFacts`, calls OpenAI server-side, sanitizes the model output, and returns a bounded fact.

The iOS app must not send prompt text, arbitrary model messages, OpenAI configuration, raw coordinates, or an OpenAI API key.

## Implementations

- iOS client: `MotoGuide/ProxyFactGenerator.swift`
- iOS token loader: `MotoGuide/KeychainCredentialLoader.swift`
- iOS tests: `MotoGuideTests/PlaceFactTests.swift`, `ProxyFactGeneratorTests`
- Proxy endpoint: `fact-proxy/src/main/java/ai/dml/motoguide/factproxy/FactController.java`
- Proxy request model: `fact-proxy/src/main/java/ai/dml/motoguide/factproxy/FactRequest.java`
- Proxy response model: `fact-proxy/src/main/java/ai/dml/motoguide/factproxy/FactResponse.java`
- Proxy docs: `fact-proxy/README.md`
- OpenAPI spec: `FACT_PROXY_OPENAPI.yaml`

## Validate The OpenAPI Spec

Exact command:

```bash
ruby -e 'require "yaml"; doc = YAML.load_file("/Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml"); abort "missing openapi" unless doc["openapi"] == "3.0.3"; abort "missing /v1/fact" unless doc.dig("paths", "/v1/fact", "post"); abort "missing FactRequest" unless doc.dig("components", "schemas", "FactRequest"); puts "OpenAPI YAML parsed: #{doc["info"]["title"]} #{doc["info"]["version"]}"'
```

Expected result:

```text
OpenAPI YAML parsed: MotoGuide Fact Proxy API 0.1.0
```

## Endpoint

Production endpoint:

```text
https://motoguide-fact-proxy.fly.dev/v1/fact
```

Local endpoint:

```text
http://127.0.0.1:3000/v1/fact
```

## Current Fly Deployment

Date verified: 2026-07-01.

| Field | Value |
|-------|-------|
| Fly app | `motoguide-fact-proxy` |
| Fly org | `dml` |
| Hostname | `motoguide-fact-proxy.fly.dev` |
| Primary region | `lhr` |
| Image | `motoguide-fact-proxy:deployment-01KWFY4N628G4137Y7BMQPN6P9` |
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
| `MOTOGUIDE_PROXY_TOKEN` | Deployed |
| `MOTOGUIDE_ADMIN_TOKEN` | Optional; enables admin diagnostics endpoint when deployed |

Runtime configuration:

| Environment variable | Default | Meaning |
|----------------------|---------|---------|
| `OPENAI_MODEL` | `gpt-4o-mini` | OpenAI model selected by the Fly runtime environment. |
| `MOTOGUIDE_DIAGNOSTICS_ENABLED` | `false` | Enables verbose proxy diagnostics at startup. |
| `MOTOGUIDE_SHORT_FACT_PROMPT` | Built-in prompt | Optional server-side prompt override for `shortFacts`. Never sent by iOS. |
| `MOTOGUIDE_LONG_FACT_PROMPT` | Built-in prompt | Optional server-side prompt override for `longFacts`. Never sent by iOS. |
| `RATE_LIMIT_PER_MINUTE` | `30` | Per-IP request limit for authenticated proxy calls. |

Health check:

```bash
curl -fsS https://motoguide-fact-proxy.fly.dev/health
```

Expected result:

```text
ok
```

If local DNS is still propagating, this equivalent command verifies the Fly public route through the assigned shared IPv4:

```bash
curl -fsS --resolve motoguide-fact-proxy.fly.dev:443:66.241.125.198 https://motoguide-fact-proxy.fly.dev/health
```

Expected result:

```text
ok
```

## Authentication

Every `POST /v1/fact` request must include:

```http
Authorization: Bearer <MOTOGUIDE_PROXY_TOKEN>
Content-Type: application/json
```

The iOS app reads this token from the iOS Keychain generic-password item with service:

```text
MotoGuideProxy
```

The OpenAI API key must stay server-side. It must be configured only on the proxy host, for example as the Fly.io secret `OPENAI_API_KEY`.

Current MVP security model:

- Transport is HTTPS through Fly.io public ingress.
- App authentication is a shared bearer token: `MOTOGUIDE_PROXY_TOKEN`.
- The app stores only the proxy token, not the OpenAI key.
- The OpenAI key is stored only as the Fly secret `OPENAI_API_KEY`.
- The proxy only exposes a narrow place-fact endpoint; clients cannot send arbitrary OpenAI prompts, model names, endpoints, or message arrays.
- The proxy validates `boundary`, `factMode`, `placeName`, `countryContext`, and `placeHierarchy`.
- The proxy rate-limits by client IP.

Current limitation:

- If `MOTOGUIDE_PROXY_TOKEN` is extracted from the app or device, the holder can call `/v1/fact` until the token is rotated, rate limits apply, or server-side controls block it.

Planned hardening:

- Per-device registration.
- Apple App Attest assertion verification.
- Server-side approved-device state with revoke/block support.
- Per-device and per-user quotas.
- Per-user authentication before wider non-TestFlight distribution.

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

Diagnostics control:

- Baseline request logs remain on so app-reported `X-Request-Id` values can be matched to Fly logs.
- Verbose diagnostics are off by default.
- Set `MOTOGUIDE_DIAGNOSTICS_ENABLED=true` to enable verbose diagnostics at process startup.
- `GET /admin/diagnostics` returns the current setting when `MOTOGUIDE_ADMIN_TOKEN` is configured.
- `PUT /admin/diagnostics` with `{"enabled": true}` or `{"enabled": false}` changes the setting for the current running proxy process.
- The admin endpoint requires `Authorization: Bearer <MOTOGUIDE_ADMIN_TOKEN>`.
- If `MOTOGUIDE_ADMIN_TOKEN` is not configured, `/admin/diagnostics` returns `404`.
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
| `fact` | Yes | String | One bounded, factual, ride-safe fact. `shortFacts` is capped at 120 characters. `longFacts` is capped at 280 characters. |

## Error Responses

| Status | Meaning | iOS behavior |
|--------|---------|--------------|
| `400` | Invalid JSON, missing required field, invalid `boundary`, invalid `factMode`, invalid `placeName`, or invalid `placeHierarchy`. | Fall back to the base place announcement. |
| `401` | Missing or wrong proxy token. | Fall back to the base place announcement. |
| `500` | Proxy is misconfigured, including missing server-side proxy token. | Fall back to the base place announcement. |
| `502` | OpenAI returned an error or unusable response. | Fall back to the base place announcement. |

The iOS app must not speak raw error text.

## Speech Safety Rules

The returned `fact` must be:

- `shortFacts`: one sentence and no more than 120 characters.
- `longFacts`: one or two short sentences and no more than 280 characters.
- Factual and neutral.
- Useful as ambient place context.
- Short enough to keep the total spoken announcement ride-safe.
- Free of questions.
- Free of invitations, route advice, speed advice, or riding instructions.

The current iOS sanitizer rejects empty facts, questions, and `you should` phrasing, and truncates facts using the selected fact mode.

## Timeout And Fallback

The iOS app uses a 3-second timeout through `PlaceFactFetcher`.

If the proxy token is missing, the request fails, the proxy returns an error, response JSON is invalid, the fact is rejected by the sanitizer, or the timeout expires, MotoGuide must speak the base place announcement without a fact.

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
  -d '{"boundary":"town","placeName":"Stroud","factMode":"shortFacts","countryContext":"United Kingdom","placeHierarchy":{"town":"Stroud","county":"Gloucestershire","region":"England","country":"United Kingdom"}}'
```

Expected result:

```json
{
  "fact": "One bounded factual sentence."
}
```

The exact sentence can vary because it is generated by the server-side LLM.

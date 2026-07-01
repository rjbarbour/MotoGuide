# MotoGuide Fact Proxy Contract

Date: 2026-07-01

Status: Human-readable companion to `FACT_PROXY_OPENAPI.yaml`.

Source of truth: `FACT_PROXY_OPENAPI.yaml`.

Keep the iOS app, fact proxy server, tests, and markdown in sync with the OpenAPI specification.

## Purpose

The fact proxy contract lets MotoGuide ask for one short place fact without storing or sending an OpenAI API key from the iOS app.

The iOS app sends a place request to the MotoGuide fact proxy. The proxy validates the request, calls OpenAI server-side, sanitizes the model output, and returns one short sentence.

## Implementations

- iOS client: `MotoGuide/ProxyFactGenerator.swift`
- iOS token loader: `MotoGuide/KeychainCredentialLoader.swift`
- iOS tests: `MotoGuideTests/PlaceFactTests.swift`, `ProxyFactGeneratorTests`
- Proxy endpoint: `/Users/rob_dev/DocsLocal/motoguide/fact-proxy/src/main/java/ai/dml/motoguide/factproxy/FactController.java`
- Proxy request model: `/Users/rob_dev/DocsLocal/motoguide/fact-proxy/src/main/java/ai/dml/motoguide/factproxy/FactRequest.java`
- Proxy response model: `/Users/rob_dev/DocsLocal/motoguide/fact-proxy/src/main/java/ai/dml/motoguide/factproxy/FactResponse.java`
- Proxy docs: `/Users/rob_dev/DocsLocal/motoguide/fact-proxy/README.md`
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
  "countryContext": "United Kingdom"
}
```

Fields:

| Field | Required | Type | Allowed values | Meaning |
|-------|----------|------|----------------|---------|
| `boundary` | Yes | String | `country`, `nation`, `county`, `town`, `street` | The boundary type that triggered the announcement. |
| `placeName` | Yes | String | Non-empty place name | The place to generate a fact about. |
| `countryContext` | No | String or `null` | Non-empty country name when known | Disambiguates places with reused names. |

The iOS app must map `BoundaryType.factLabel` directly to `boundary`.

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
| `fact` | Yes | String | One short, factual, ride-safe sentence. |

## Error Responses

| Status | Meaning | iOS behavior |
|--------|---------|--------------|
| `400` | Invalid JSON, missing `boundary`, invalid `boundary`, or missing `placeName`. | Fall back to the base place announcement. |
| `401` | Missing or wrong proxy token. | Fall back to the base place announcement. |
| `500` | Proxy is misconfigured, including missing server-side proxy token. | Fall back to the base place announcement. |
| `502` | OpenAI returned an error or unusable response. | Fall back to the base place announcement. |

The iOS app must not speak raw error text.

## Speech Safety Rules

The returned `fact` must be:

- One sentence.
- Factual and neutral.
- Useful as ambient place context.
- Short enough to keep the total spoken announcement ride-safe.
- Free of questions.
- Free of invitations, route advice, speed advice, or riding instructions.

The current iOS sanitizer rejects empty facts, questions, and `you should` phrasing, and truncates facts to 120 characters.

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
  -d '{"boundary":"town","placeName":"Stroud","countryContext":"United Kingdom"}'
```

Expected result:

```json
{
  "fact": "One short factual sentence."
}
```

The exact sentence can vary because it is generated by the server-side LLM.

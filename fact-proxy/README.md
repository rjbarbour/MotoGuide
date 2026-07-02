# MotoGuide fact proxy

Java 25 / Spring Boot thin HTTP proxy: MotoGuide iPhone → this service → OpenAI. The OpenAI API key and prompt text live only on the server, not on the device.

OpenAPI contract source: `/Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml`.

Human-readable companion: `/Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_CONTRACT.md`.

## Prerequisites

- [SDKMAN](https://sdkman.io/) for local Java (do not use Homebrew OpenJDK for this project)
- [flyctl](https://fly.io/docs/hands-on/install-flyctl/) for deploy

```bash
cd /Users/rob_dev/DocsLocal/motoguide/repo/fact-proxy
sdk env install   # installs Java 25.0.3-tem from .sdkmanrc
sdk env           # activates Java 25 in this shell
```

To see available Java 25 builds: `sdk list java | rg 25`

## Build and test

One-time: install Java 25 from `.sdkmanrc`. The Gradle wrapper uses Gradle 9.6.1 because Gradle 8.x cannot run on Java 25.

```bash
./clean.sh      # optional — clears stale .gradle-user / build dirs
./build.sh
```

Expected result: tests pass and `build/libs/fact-proxy.jar` is created.

Or manually:

```bash
sdk env
./gradlew test bootJar --no-daemon
```

Expected result: `BUILD SUCCESSFUL` and JAR output at `build/libs/fact-proxy.jar`.

## Local run

```bash
sdk env
export OPENAI_API_KEY="sk-..."
export MOTOGUIDE_PROXY_TOKEN="dev-token"
./gradlew bootRun --no-daemon
```

Or run the JAR:

```bash
java -jar build/libs/fact-proxy.jar
```

Expected result: Spring Boot starts on `http://127.0.0.1:3000`.

## API

This section summarizes the contract. Keep it aligned with `/Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml`.

Validate the OpenAPI file without simulator or deployment:

```bash
ruby -e 'require "yaml"; doc = YAML.load_file("/Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml"); abort "missing openapi" unless doc["openapi"] == "3.0.3"; abort "missing /v1/fact" unless doc.dig("paths", "/v1/fact", "post"); abort "missing FactRequest" unless doc.dig("components", "schemas", "FactRequest"); puts "OpenAPI YAML parsed: #{doc["info"]["title"]} #{doc["info"]["version"]}"'
```

Expected result: `OpenAPI YAML parsed: MotoGuide Fact Proxy API 0.1.0`.

### `GET /health`

Returns `200` with body `ok`.

### `POST /v1/fact`

**Headers**

- `Authorization: Bearer <MOTOGUIDE_PROXY_TOKEN>` (required)
- `Content-Type: application/json`

**Body**

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
    "familiarRegions": ["England", "Cotswolds"]
  }
}
```

`boundary` is one of: `country`, `nation`, `county`, `town`, `street`.
`factMode` is one of: `shortFacts`, `longFacts`. Unknown modes return `400` before any OpenAI call.
The iOS app sends place hierarchy only. It does not send prompt text, model messages, OpenAI configuration, or coordinates.

**Response `200`**

```json
{
  "fact": "A compact historical or practical rider-relevant fact."
}
```

**Errors**

- `401` — missing or wrong proxy token
- `400` — invalid JSON or missing fields
- `502` — OpenAI error or unusable response

### Test with curl

```bash
curl -sS http://127.0.0.1:3000/health

curl -sS -X POST http://127.0.0.1:3000/v1/fact \
  -H "Authorization: Bearer dev-token" \
  -H "Content-Type: application/json" \
  -d '{"boundary":"town","placeName":"Stroud","factMode":"shortFacts","countryContext":"United Kingdom","placeHierarchy":{"town":"Stroud","county":"Gloucestershire","region":"England","country":"United Kingdom"},"riderContext":{"homeCountry":"United Kingdom","homeRegion":"West Midlands","familiarRegions":["England","Cotswolds"]}}'
```

## Fly.io deploy

```bash
cd /Users/rob_dev/DocsLocal/motoguide/repo/fact-proxy

# Option A: manual deploy (current)
./build.sh
fly deploy

# Option B: Terraform-managed app shell + GitHub Action deployment
cd fact-proxy/terraform
FLY_API_TOKEN=fo1_... terraform init -input=false
FLY_API_TOKEN=fo1_... terraform apply

cd ..
flyctl deploy --config fly.toml
```

GitHub Action for this flow: `.github/workflows/fact-proxy-deploy.yml`

Secrets are managed through GitHub repository/organization secrets and injected at runtime:

```bash
FLY_API_TOKEN=fo1_...
OPENAI_API_KEY=sk-...
MOTOGUIDE_PROXY_TOKEN=...
```

Then secrets are set via:

```bash
fly secrets set \
  OPENAI_API_KEY="sk-..." \
  MOTOGUIDE_PROXY_TOKEN="$(openssl rand -hex 24)"
```

After deploy:

```bash
fly status
curl -sS https://motoguide-fact-proxy.fly.dev/health
```

Store `MOTOGUIDE_PROXY_TOKEN` in the iOS app Keychain (service `MotoGuideProxy`) — **not** the OpenAI key.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes | OpenAI key (Fly secret only) |
| `MOTOGUIDE_PROXY_TOKEN` | Yes | Shared secret the app sends as Bearer token |
| `OPENAI_MODEL` | No | Fly runtime variable. Default `gpt-4o-mini` in `fly.toml` |
| `MOTOGUIDE_SHORT_FACT_PROMPT` | No | Optional server-side prompt override for `shortFacts` |
| `MOTOGUIDE_LONG_FACT_PROMPT` | No | Optional server-side prompt override for `longFacts` |
| `PORT` | No | Default `3000` |
| `RATE_LIMIT_PER_MINUTE` | No | Default `30` per client IP |
| `MOTOGUIDE_PROMPT_OVERRIDES_ENABLED` | No | Default `false`; enables remote prompt override loading |
| `MOTOGUIDE_PROMPT_OVERRIDES_OBJECT_URL` | No | Object-store URL for JSON prompt overrides |
| `MOTOGUIDE_PROMPT_OVERRIDES_REFRESH_SECONDS` | No | Cache refresh interval; default `60` |
| `MOTOGUIDE_PROMPT_OVERRIDES_AUTH_TOKEN` | No | Optional bearer token for object-store retrieval |

## iOS integration

The iOS app uses `ProxyFactGenerator` to call `https://motoguide-fact-proxy.fly.dev/v1/fact`.

Store `MOTOGUIDE_PROXY_TOKEN` in the iOS Keychain service `MotoGuideProxy`. Do not store the OpenAI key on the device.

## Security notes

- Minimal MVP proxy, not a full product backend.
- Use a long random `MOTOGUIDE_PROXY_TOKEN` and rotate if leaked.
- Set OpenAI usage limits in the OpenAI dashboard.
- Add per-rider auth before wider distribution.

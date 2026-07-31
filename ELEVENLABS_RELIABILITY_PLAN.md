# ElevenLabs Reliability Plan

Date: 2026-07-17

## Purpose

Make Premium Voice (ElevenLabs) reliable for RideHorizon private-beta testing. This document is the operational handoff for the voice/proxy track; keep layout work separate.

## Rider-network timeout policy

Date: 2026-07-31

The private-beta client must tolerate both Fly availability transitions and intermittent mobile data without speaking stale announcements:

- Keep one Fly proxy machine running during the TestFlight window.
- Give each fact or speech HTTP attempt up to 35 seconds because the proxy may wait up to 30 seconds for OpenAI or ElevenLabs.
- Bound the complete fact or Premium Voice operation to 60 seconds.
- Retry transient connection failures and HTTP 408/502/503/504 after 3 seconds and 10 seconds, subject to the remaining operation budget.
- Do not retry ordinary 4xx responses. Preserve the existing one-time 401 session refresh.
- For structured Premium Voice failures, retry only `RH-TTS-04`; do not retry authentication, account-capacity or throttling categories.
- Bound automatic session provisioning to 30 seconds using the same transient-failure rules.
- Honour task cancellation during requests and backoff. When a newer boundary supersedes an older request, the older request must not speak Premium Voice or trigger Apple fallback.

This is a reversible client reliability policy and does not change the proxy HTTP interface or trust boundary, so it does not require an ADR.

## Active Fix: Renamed Proxy Credential

Date: 2026-07-17

Request: make the new `RideHorizonProxy` credential work through the live Fly proxy for ElevenLabs speech.

Confirmed cause:

- Fly release `v20` reused the same image as `v19`: `registry.fly.io/motoguide-fact-proxy:deployment-01KWJPMZVKJT1TAYS38551XCJ3`.
- That image was originally deployed on 2026-07-03 and still accepts the legacy MotoGuide credential.
- The current renamed source reads `RIDEHORIZON_PROXY_TOKEN`, but that source has not been deployed to the live legacy host.

Acceptance criteria:

1. The renamed proxy source passes its automated tests and production build locally.
2. An authenticated `POST /v1/speech` using the `RideHorizonProxy` Keychain credential returns HTTP `200`, `audio/mpeg`, and non-empty playable audio from the live Fly host.
3. No credential value appears in source, commands, logs, documentation, or chat.
4. The legacy credential is not copied or migrated into the renamed app.
5. The deployed secret-storage exception described below is resolved or explicitly approved before deploying renamed code.

Status after deployment:

- The renamed RideHorizon proxy image was deployed to the existing private-beta host on 2026-07-17.
- The `RideHorizonProxy` credential is accepted by the live proxy. The previous HTTP `401` at the proxy boundary is resolved.
- The request now reaches ElevenLabs, which returns HTTP `401`; the proxy correctly maps that upstream failure to HTTP `502`.
- A controlled rollback to the unchanged 2026-07-03 proxy image produced the same ElevenLabs failure. This rules out the RideHorizon package/configuration rename as the cause.
- ElevenLabs documents HTTP `401` as an invalid or missing API credential. A replacement ElevenLabs credential is therefore required before live audio can pass acceptance criterion 2.

## Rider-Safe Provider Failures

Date: 2026-07-17

Request: pass enough information through the proxy to diagnose ElevenLabs failures without showing riders account, credit, quota, authentication, or billing details.

Design:

- Return the neutral message `Premium voice is temporarily unavailable.` for every ElevenLabs upstream failure.
- Include one stable, opaque RideHorizon diagnostic code:
  - `RH-TTS-01`: provider authentication or server configuration.
  - `RH-TTS-02`: provider account capacity.
  - `RH-TTS-03`: provider throttling.
  - `RH-TTS-04`: other provider or transport failure.
- Never return or log the raw ElevenLabs response body or account message.
- The iOS app may show the neutral message and opaque code in Test Mode diagnostics. It must not translate `RH-TTS-02` into rider-facing credit or billing language.

Acceptance criteria:

1. ElevenLabs quota/credit responses map to HTTP `502`, neutral text, and `RH-TTS-02`.
2. Authentication, throttling, and generic failures map to their stable codes.
3. The iOS speech client preserves the diagnostic code instead of reducing every response to an HTTP number.
4. Unit tests prove the mapping and prove raw upstream messages are absent from proxy responses.
5. Live TTS still returns playable MPEG audio after deployment.

Implementation status on 2026-07-17:

- Proxy classification and neutral-response tests pass.
- At that checkpoint, the OpenAPI speech error contract parsed and recorded the then-current `15 s` iOS timeout. The 2026-07-31 rider-network policy above supersedes it.
- The rider-safe proxy change was deployed from an isolated build so concurrent database-provisioning work in the shared checkout was not modified or included prematurely.
- Live acceptance passed with HTTP `200`, `audio/mpeg`, 50,199 bytes, and a 2.47-second warm response.
- The iOS client compiles and recognizes only the four allowed opaque codes. Focused simulator tests could not launch because the Mac volume ran out of space; no test assertion failed.

## Current State

```text
RideHorizon iOS app → authenticated Fly proxy → ElevenLabs text-to-speech API → MPEG audio → iOS playback
```

- The original RideHorizon host, `https://ridehorizon.digitalmercenaries.ai`, did not resolve on 2026-07-17. No request could reach the proxy through that hostname.
- The existing endpoint, `https://motoguide-fact-proxy.fly.dev`, returned `ok` from `/health` after a Fly cold start. The current iOS private-beta build uses this endpoint through `FactProxyContract.useLegacyProductionProxy = true` in `RideHorizon/ProxyFactGenerator.swift`.
- The app has a new bundle identifier, `ai.digitalmercenaries.ridehorizon`, and its proxy credentials belong only in Keychain services `RideHorizonProxy` and `RideHorizonDeviceId`.
- The new app cannot read a former MotoGuide Keychain item: the changed bundle identifier changes the default Keychain access group. Do not copy or migrate the old credential.
- No authenticated `/v1/speech` request has yet been observed from the renamed app. Therefore there is no evidence of an ElevenLabs API, model, voice, output-format, or audio-playback failure.
- Attempts to read Fly logs from this environment returned HTTP 401. No credentials were requested, printed, copied, or changed.
- On-device Preview Voice diagnostics on 2026-07-17 reported **Missing proxy token**. The proxy and ElevenLabs were not contacted.

## Superseded Access-Flow History

The material in this section through **Active Slice: Private-Alpha Token Provisioning** records the pre-2026-07-31 diagnostic and invite-based design. It is not an active operator procedure. The invite UI, invite endpoints, shared-token importer, credential authority, and invite tables were removed for the first TestFlight beta. Current builds obtain restricted short-lived sessions automatically through `/v1/session/fallback` and renew after a `401` without tester input.

### Why the Development Token Was Missing

The former development path is `DebugProxyTokenImporter` in `RideHorizon/KeychainCredentialLoader.swift`, invoked only by the `#if DEBUG` block in `RideHorizon/RideHorizonApp.swift`. It reads `RIDEHORIZON_PROXY_TOKEN` from an Xcode launch-scheme environment and writes it to `RideHorizonProxy` in the app Keychain.

`xcrun devicectl` launch does not receive the Xcode scheme environment, so that importer was not given a value. TestFlight release builds also exclude it. This path is development-only and must not be used for TestFlight provisioning.

### What Was Proven vs. Unknown

| Layer | Status | Evidence |
|---|---|---|
| iPhone signing and USB deployment | Working | Physical device build/install/launch passed on 2026-07-17. |
| Old Fly host DNS and health | Working, with cold start | `/health` returned `ok`; first 10-second request timed out while the machine started. |
| New RideHorizon hostname | Broken | DNS resolution failed on 2026-07-17. |
| App → Fly authenticated request | Not yet tested | RideHorizon needs its own Keychain proxy token. |
| Fly → ElevenLabs | Not yet tested | Requires a successful authenticated speech request. |
| ElevenLabs audio → iOS playback | Not yet tested | Requires returned audio from the proxy. |

### Security Constraints

Follow `AGENTS.md` and AXON **SOP: Secret Management in Agentic AI Development v3.0** before any secret-related action.

- Never put API keys, proxy tokens, device IDs, or credential-like values in source, docs, logs, shell history, Xcode scheme variables, or chat.
- The phone stores only the proxy credential in its own Keychain. It never receives an ElevenLabs key.
- Fly Secrets is an approved platform-native secret store for this Fly.io-hosted private-alpha workload under the 2026-07-17 AXON SOP exception. Secret values must still never enter source, repository files, logs, documentation, databases as plaintext application credentials, or chat.
- The temporary old Fly endpoint is for this private-beta diagnostic phase only. Remove it after the RideHorizon hostname and compliant service are live.

### Former Diagnostic Sequence

1. For local debug only, provision a valid proxy token directly into the RideHorizon Keychain service `RideHorizonProxy` using an approved local-only mechanism. Do not use Xcode environment injection, paste a value into chat, or rely on the old app Keychain item.
2. In the app, enable Proxy Diagnostics and select **Premium voice (ElevenLabs)**.
3. In Test Mode, trigger the first test location and inspect the visible diagnostic note and debug log.
4. Classify the result:

| Result | Meaning | Next action |
|---|---|---|
| Missing proxy token | Device setup incomplete | Provision token to `RideHorizonProxy`. |
| HTTP 401/403 | Proxy token or device binding failed | Check token validity and whether device binding is enabled. |
| HTTP 500 | Fly received the request but upstream/service configuration failed | Safely inspect Fly log events and secret *names*, never values. |
| Timeout/network failure | Fly cold start, connectivity, or host issue | Retry after cold start; then inspect service status. |
| HTTP 200 but no playback | iOS audio format/session/player issue | Inspect content type, audio byte count, and AVAudioPlayer diagnostics. |

5. After a reproducible failure, change the smallest responsible layer, run the relevant tests, build for the physical iPhone, and test again through the helmet headset.

### Former TestFlight Provisioning Design

Do not embed or manually distribute one shared proxy bearer token in a TestFlight build. Implement an authenticated bootstrap flow instead:

1. A tester receives an invite or signs in with an approved identity method.
2. The app exchanges that invite/identity proof with a backend registration endpoint.
3. The backend creates a revocable, scoped, per-tester or per-device access token.
4. The app stores that issued token in `RideHorizonProxy`.
5. The proxy accepts that token and enforces rate limits/revocation; later add App Attest/DeviceCheck where appropriate.

This is the route for private beta. A manual secure entry UI may be acceptable for one developer device, but is not a tester-provisioning system.

### Former Slice: Private-Alpha Token Provisioning

Date: 2026-07-17

Goal: allow a clean development or TestFlight installation to obtain its own revocable proxy credential without embedding or manually copying a shared bearer token.

Public behavior:

1. An operator creates a one-time invite code through an authenticated administrative endpoint.
2. Only a one-way hash of the invite code is persisted. The plaintext code is returned once and must not be logged.
3. The iOS app redeems the invite code with its stable Keychain-backed device identifier.
4. The backend consumes the invite atomically and returns a new random device credential once over TLS.
5. Only a one-way hash of the device credential is persisted, with device identifier, creation time, expiry, last-use time, and revocation state.
6. The app stores the issued credential in the `RideHorizonProxy` Keychain service and removes the invite code from memory.
7. Protected proxy endpoints accept active database-backed credentials, reject expired or revoked credentials, and retain the current shared Fly Secret only as a temporary operator/developer fallback.
8. An authenticated administrative endpoint can revoke a device credential without learning its plaintext value.

Acceptance criteria:

1. Database migrations create the invite and device-credential tables automatically and idempotently.
2. A valid unused invite can be redeemed once; reuse, expiry, and invalid input are rejected without revealing which condition applied.
3. Issued credentials contain at least 256 bits of randomness and are never stored or logged in plaintext.
4. Database-backed credentials authorize `/v1/fact` and `/v1/speech`; revoked and expired credentials return HTTP `401`.
5. Administrative creation and revocation require the existing administrative authentication mechanism and are rate-limited appropriately.
6. A clean iOS installation can redeem an invite, persist the credential in Keychain, and use it after relaunch.
7. Backend integration tests cover issue, redeem, authenticate, expire, revoke, and concurrent double-redemption behavior.
8. The deployed proxy passes health, provisioning, authentication, and ElevenLabs speech smoke tests without exposing secrets.

Design seam:

- `CredentialAuthority` is the small backend interface used by HTTP authentication and provisioning callers. It owns generation, hashing, expiry, atomic redemption, validation, last-use tracking, and revocation.
- PostgreSQL is the production adapter. Backend tests exercise behavior through HTTP interfaces with a database adapter rather than depending on implementation details.
- `ProxyCredentialProvisioner` is the iOS interface that exchanges an invite for a credential and stores it through the existing Keychain module.

Status on 2026-07-17:

- Unmanaged PostgreSQL app `ridehorizon-beta-db` is healthy in Fly region `lhr` with 1 shared CPU, 512 MB RAM, and a 1 GB encrypted volume.
- `DATABASE_URL` is deployed to the live private-alpha proxy through Fly Secrets.
- Flyway migration V1 created the invite and device-credential schema.
- Live proxy deployment version 30 passed the complete status-only smoke test: invite `201`, redemption `201`, authenticated fact `200`, ElevenLabs MPEG speech `200`, revocation `204`, revoked credential `401`.
- All smoke-test credentials were revoked; no plaintext invite, credential, database password, provider key, or audio was persisted or printed.
- The iOS app presents the private-beta invite screen only when `RideHorizonProxy` is absent, stores issued credentials in Keychain, binds requests to the stable Keychain device ID, and returns to provisioning automatically after an authentication `401`.
- The final backend and iOS test suites pass. The final device build installed and launched on the physical iPhone as RideHorizon v0.12.3 (20260708.1650).

## Safe Operator Checks

Run locally only when logged into Fly. These commands must reveal names/status, not secret values:

```bash
fly secrets list --app motoguide-fact-proxy
# Expected: secret names only.

fly status --app motoguide-fact-proxy
# Expected: running/started machine information.

fly logs --app motoguide-fact-proxy --no-tail
# Expected: recent event logs; do not enable verbose/debug credential output.
```

Relevant configuration names in the current source template are `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`, `ELEVENLABS_MODEL_ID`, and `ELEVENLABS_OUTPUT_FORMAT`. Their values are sensitive and must never be recorded.

## Code Ownership Boundaries

Voice/proxy track:

- `RideHorizon/ProxyFactGenerator.swift`
- `RideHorizon/KeychainCredentialLoader.swift`
- `RideHorizon/LocationManager.swift`
- `fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/ElevenLabsSpeechService.java`
- `fact-proxy/src/main/java/ai/digitalmercenaries/ridehorizon/factproxy/FactController.java`
- related voice/proxy tests

Layout track:

- `RideHorizon/ContentView.swift`
- `RideHorizon/OnboardingView.swift`
- image assets and attribution

`ContentView.swift` contains Settings and diagnostics UI as well as layout. Coordinate before editing it from both tracks; prefer adding new focused views/files for voice diagnostic UI.

## Existing Documentation

- Product and UI plan: `MVP_POLISH_PLAN.md`
- Identity and deployment constraint: `REBRANDING_PLAN.md`
- HTTP contract: `FACT_PROXY_OPENAPI.yaml` and `FACT_PROXY_CONTRACT.md`
- Image licensing: `ONBOARDING_IMAGE_ATTRIBUTION.md`
- Project rules: `AGENTS.md`

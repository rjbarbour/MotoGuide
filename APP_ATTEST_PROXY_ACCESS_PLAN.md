# RideHorizon Anonymous Proxy Access Plan

Date: 2026-07-18

Status: Approved for implementation

## Private TestFlight Release Decision — 2026-07-31

For the first named private beta, full App Attest verification is deferred until after the initial TestFlight build. This is not an Apple TestFlight requirement. The release candidate will use automatic restricted fallback sessions with no login, invite code, shared app credential, or manual token entry.

The fallback release gate is:

- sessions renew automatically after expiry and retry one failed proxy request once;
- fallback usage is persistently limited per anonymous installation plus globally;
- the public fallback endpoint is IP rate-limited;
- facts and Premium Voice work through the deployed proxy on a clean installation;
- upstream credentials remain only in Fly Secrets;
- App Attest can replace the fallback path later without changing the rider-facing flow.

## Outcome

RideHorizon users, TestFlight testers, and Apple App Review must be able to open the app and use proxy-backed facts and speech without an account, invite code, or manual credential setup.

The ElevenLabs and OpenAI API keys remain only in Fly Secrets. A genuine RideHorizon installation proves its identity with Apple App Attest and automatically receives a short-lived proxy access token. Server-side quotas limit abuse and protect the available upstream credits.

## Decisions

- Remove the visible private-beta invite-code gate.
- Do not embed a permanent shared proxy token in the app.
- Do not require Sign in with Apple or any other user account for MVP1.
- Use Apple App Attest as the normal anonymous installation-authentication mechanism.
- Issue short-lived, opaque bearer tokens after successful attestation or assertion verification.
- Retain a restricted automatic fallback for unsupported devices and temporary Apple/App Attest failures.
- Enforce per-installation, per-IP, and global usage controls on the proxy.
- Keep upstream API keys and administrative credentials only in Fly Secrets.
- Treat TestFlight and App Store builds as the production App Attest environment; keep development attestations separate.

## Why

TestFlight controls who can install a beta, but it does not protect a shared API credential embedded in the binary. Invite codes add tester and App Review friction and are not an Apple requirement. App Attest provides an anonymous device-bound cryptographic identity without asking the rider to create an account.

App Attest does not replace rate limiting. A genuine installation can still be automated or abused, and restricted fallback traffic is deliberately possible. The proxy therefore remains the policy and budget enforcement point.

## User Experience

Normal first launch:

1. The app starts normally; there is no access-code screen.
2. Proxy access is provisioned automatically in the background.
3. Names-only and Apple speech remain available while provisioning is pending or unavailable.
4. Proxy-backed facts and ElevenLabs speech become available as soon as a session is established.
5. Temporary failures produce the existing non-blocking fallback behaviour and a useful diagnostic message in Test Mode.

The user must never need to understand App Attest, tokens, Fly, or ElevenLabs.

## Target Architecture

### Trust boundaries

- **iOS app:** owns an App Attest private key protected by the device and a short-lived proxy session token. It never contains an upstream API key or administrative credential.
- **RideHorizon proxy:** verifies Apple attestations and assertions, issues and validates proxy sessions, applies quotas, and calls upstream services.
- **Apple App Attest:** certifies that a cryptographic key belongs to a legitimate instance of the registered RideHorizon app.
- **PostgreSQL:** stores public attestation records, one-time challenges, hashed session tokens, counters, status, and usage totals. It stores no plaintext bearer token.
- **Fly Secrets:** canonical store for upstream and administrative secrets used by the Fly workload.

### Normal provisioning flow

1. The app calls a public challenge endpoint.
2. The proxy creates a cryptographically random, single-use challenge with a short expiry.
3. The app creates an App Attest key when it has no usable key identifier.
4. The app asks Apple to attest the key using a hash that binds the server challenge to the request.
5. The app sends the attestation object, key identifier, challenge identifier, and required client data to the proxy.
6. The proxy performs every validation required by Apple's current Attestation Object Validation Guide, including certificate chain, nonce, app identity, environment, credential, and replay checks.
7. The proxy stores the verified public key and initial counter, associated with an opaque installation record.
8. The proxy issues a random short-lived bearer token. Only its one-way hash is stored.
9. The app stores the bearer token in the existing `RideHorizonProxy` Keychain service and stores the App Attest key identifier in a separate non-secret persistent item.

### Session renewal flow

1. Before expiry, or after an authenticated request returns `401`, the app requests a fresh one-time challenge for its App Attest key identifier.
2. The app creates an App Attest assertion covering the challenge and canonical request data.
3. The proxy verifies the signature, app identity, challenge, and strictly increasing assertion counter against the stored public key.
4. The proxy revokes or expires the previous session and returns a new short-lived bearer token.
5. The app replaces the old Keychain value atomically and retries the original operation once.

Use a default session lifetime of one hour. Make it non-secret server configuration so it can be tuned without changing the app.

### Restricted fallback

Fallback exists to preserve access for Apple reviewers, unsupported devices, and temporary App Attest service failures. It is not equivalent to verified access.

- Use fallback only when App Attest reports unsupported or a genuine provisioning attempt fails for a transient service/network reason.
- Do not silently downgrade an explicitly invalid attestation or assertion.
- Give fallback installations an opaque server-issued session and a lower daily allowance.
- Apply strict IP burst limits and the global circuit breaker.
- Record only a bounded failure category; never log attestation objects, assertions, tokens, raw IP addresses, or device identifiers.
- Allow a previously verified installation to renew through a controlled grace path during a temporary Apple outage.
- The app continues with base announcements if even restricted fallback is unavailable.

Because a hostile client can imitate the fallback path, fallback safety comes from its low quota and the global ceiling, not from trusting a client-supplied installation identifier.

## HTTP Contract

Final endpoint names may be adjusted to fit the existing controller conventions, but the contract must provide these operations:

| Operation | Authentication | Purpose |
|---|---|---|
| `POST /v1/attestation/challenge` | Public, IP-limited | Create a short-lived, single-use registration challenge. |
| `POST /v1/attestation/register` | Valid Apple attestation | Register an App Attest public key and issue the first session. |
| `POST /v1/session/challenge` | Key identifier plus IP limits | Create a short-lived, single-use assertion challenge. |
| `POST /v1/session/renew` | Valid App Attest assertion | Renew a verified short-lived session. |
| `POST /v1/session/fallback` | Public, heavily limited | Issue a restricted fallback session for an allowed failure category. |
| `POST /v1/fact` | Valid session bearer token | Generate a place fact. |
| `POST /v1/speech` | Valid session bearer token | Generate ElevenLabs audio. |

Contract requirements:

- Challenge values contain at least 256 bits of randomness, expire within five minutes, and are consumed atomically once.
- Session tokens contain at least 256 bits of randomness and are returned only once over TLS.
- Store only hashes of session tokens.
- Bound and validate every request field before cryptographic or upstream processing.
- Use generic client-facing authentication failures without revealing validation internals.
- Never include credential material in logs, metrics, exception messages, documentation, or tests.
- Update `FACT_PROXY_OPENAPI.yaml` and `FACT_PROXY_CONTRACT.md` in the same change as the implementation.

## Database Changes

Add migrations rather than editing an applied migration.

Required logical records:

### Attested installation

- Internal UUID.
- App Attest key identifier or a non-reversible lookup representation where practical.
- Verified public key.
- Environment: development or production.
- Last accepted assertion counter.
- Created, last-seen, revoked, and optional grace timestamps.
- Status and bounded diagnostic category.
- No personal identity is required.

### One-time challenge

- Internal UUID.
- Hash of challenge material.
- Purpose: registration or renewal.
- Optional installation association.
- Created, expiry, and consumed timestamps.
- Attempt count or terminal state to prevent replay and brute-force reuse.

### Proxy session

- Internal UUID.
- Session-token hash.
- Verified installation association, or restricted-fallback classification.
- Created, expiry, last-used, and revoked timestamps.
- Never store the plaintext token.

### Usage accounting

- Installation or fallback bucket.
- UTC quota window.
- Fact request count.
- ElevenLabs character count or the closest deterministic pre-request cost unit.
- Rejected request count where operationally useful.
- A global UTC usage bucket for the circuit breaker.

Use atomic database updates for challenge consumption, assertion-counter advancement, quota reservation, and session replacement. Concurrent requests must not bypass limits.

## Usage Controls

Start with conservative, configurable defaults and tune them from observed beta usage:

- Verified per-installation request burst limit.
- Lower fallback burst limit.
- Verified daily ElevenLabs character allowance.
- Much lower fallback daily character allowance.
- Secondary IP limit for registration, fallback provisioning, and unusual bursts.
- Maximum input characters and maximum generated audio size.
- Global daily ElevenLabs character ceiling.
- Global upstream-error circuit breaker with bounded recovery.

Reserve quota atomically before calling ElevenLabs. Define whether failed upstream calls release the reservation; default to retaining the reservation when upstream billing may already have occurred. Return `429` with a non-sensitive retry indication when a quota is exhausted.

The existing in-memory minute limiter can remain as a first defensive layer, but persistent daily and global limits must live in PostgreSQL so restarts or multiple Fly machines cannot reset or bypass them.

## iOS Work

1. Add the App Attest capability and correct entitlement configuration for Debug and distribution builds.
2. Add a focused App Attest client abstraction around `DCAppAttestService` so Apple APIs can be mocked in unit tests.
3. Add an anonymous proxy-session coordinator responsible for registration, renewal, fallback, Keychain persistence, and one controlled retry.
4. Keep authentication out of `ProxyFactGenerator` and speech-generation details; those clients should ask the coordinator for a valid session.
5. Remove `PrivateBetaAccessView`, invite-code state, and invite redemption from `RideHorizonApp.swift`.
6. Replace `ProxyCredentialProvisioner` and debug shared-token importing with the new coordinator. Do not retain a production path that imports a shared bearer token.
7. Preserve base announcements and Apple speech when proxy access is unavailable.
8. Add bounded diagnostics for provisioning state: not started, attesting, verified, restricted fallback, temporarily unavailable, quota exhausted, and rejected.
9. Ensure logs never include key identifiers, challenge data, attestation/assertion blobs, session tokens, raw device identifiers, or exact rider location.

## Proxy Work

1. Add a small `AppAttestationAuthority` interface and keep Apple validation, persistence, session issuance, and HTTP controllers as separate modules.
2. Implement Apple attestation and assertion verification exactly against Apple's current documentation and production/development trust anchors. Do not invent or weaken cryptographic validation.
3. Add replay-safe challenge storage and atomic assertion-counter updates.
4. Adapt the existing database-backed credential authentication seam to short-lived verified and restricted sessions.
5. Add persistent quota accounting and a global circuit breaker before upstream calls.
6. Add explicit response categories for transient App Attest failure, invalid proof, session expiry, and quota exhaustion without exposing sensitive details.
7. Keep administrative authentication separate. Administrative credentials remain Fly Secrets and are never accepted as ordinary app authentication after migration.
8. Keep upstream ElevenLabs and OpenAI keys exclusively in Fly Secrets.

## Removal of the Invite System

Remove the invite mechanism as part of this implementation, rather than leaving it as a user-facing legacy path:

- Remove the iOS invite screen, model, redemption request, copy, and tests.
- Remove `/admin/v1/invites` and invite redemption at `/v1/provision` after the automatic path passes end-to-end tests.
- Remove invite-specific Java interfaces, controller methods, configuration, tests, and documentation.
- Add a later migration that drops `rh_invite_codes` after no deployed build depends on it. Because the app has not entered public production, this can occur in the same release once compatibility has been confirmed.
- Replace long-lived device credentials with short-lived session records. Revoke existing private-alpha credentials at cutover.
- Retain a shared proxy token only if an explicit local/operator diagnostic use case remains. It must come from the approved runtime secret store, must not ship in iOS, and must not authenticate public app endpoints in production.

## Secret Handling

Follow `SOP: Secret Management in Agentic AI Development v3.0` throughout implementation.

- Fly-hosted secret values remain in Fly Secrets and reach the service only through Fly's managed runtime delivery.
- Local long-lived values remain in macOS Keychain and are retrieved at runtime.
- Do not place secret values in source, `.env` files, Xcode schemes, command arguments, shell history, documentation, tests, logs, chat, PostgreSQL, or CI output.
- Public App Attest identifiers, public keys, challenge hashes, token hashes, counters, and non-secret configuration are not upstream API secrets, but still require minimisation and safe logging.
- Run the repository's secret scanning checks before deployment.

## Privacy and App Review

- Collect no user account or direct identity for anonymous access.
- Use the attested installation record only for service security, quota enforcement, revocation, and reliability.
- Define a retention period and delete inactive installation, session, challenge, and detailed usage records automatically.
- Reassess the App Store privacy questionnaire and privacy policy for device identifiers, diagnostics, and usage data before submission.
- In TestFlight and App Review notes state: `No account or access code is required. Network services are provisioned automatically at first launch.`
- Keep the production proxy available throughout review.
- Confirm on a clean TestFlight installation that Apple reviewers cannot encounter a developer-only credential dependency.

## Implementation Sequence

### Execution tracker (2026-07-18)

- Status: In progress.
- Scope: remove invite-based access, add App Attest-like session endpoints with registration/renew/fallback, remove iOS gate, add token persistence + provisioning state, and enforce persistent usage limits in the proxy.

### Phase 1: Contract and test scaffolding

- Update the OpenAPI and prose contracts first.
- Define App Attest client/server interfaces and deterministic test fixtures.
- Add database migrations for challenges, attested installations, sessions, and usage accounting.
- Add tests for schemas and atomic operations.

### Phase 2: Proxy verification and sessions

- Implement challenge creation and consumption.
- Implement development and production attestation validation.
- Implement assertion validation and counter advancement.
- Issue, hash, expire, revoke, and renew short-lived sessions.
- Add restricted fallback sessions.
- Cover all endpoints with integration tests.

### Phase 3: Persistent quotas

- Add per-installation/fallback daily accounting.
- Add global quota reservation and circuit breaker.
- Apply limits consistently to facts and speech, with character-based accounting for ElevenLabs.
- Add concurrency and restart-safe tests.

### Phase 4: iOS automatic provisioning

- Add entitlements and the App Attest client abstraction.
- Add automatic registration, renewal, restricted fallback, and Keychain session storage.
- Route fact and speech authentication through the session coordinator.
- Remove the invite gate and invite redemption code.
- Add unit tests using mocked App Attest and networking.

### Phase 5: Cutover and cleanup

- Deploy the proxy with both the new path and existing developer access only for the shortest necessary migration window.
- Install a clean development build and validate development attestation.
- Upload a TestFlight build and validate production attestation on a clean install.
- Verify facts and ElevenLabs audio end to end.
- Verify unsupported/transient fallback and quota exhaustion behaviour.
- Remove invite endpoints, code, tests, configuration, and schema after compatibility is confirmed.
- Revoke old device and shared app credentials.
- Update operational and App Review documentation.

## Test Matrix

Backend automated tests must cover:

- Challenge randomness, expiry, atomic single use, and replay rejection.
- Valid development and production attestation fixtures.
- Wrong bundle/app identity, environment, nonce, certificate chain, credential, and malformed CBOR rejection.
- Valid assertion, bad signature, repeated/decreased counter, wrong challenge, and revoked installation rejection.
- Session issue, expiry, replacement, revocation, and token-hash-only persistence.
- Verified and restricted-fallback quota differences.
- Concurrent quota reservation and global circuit-breaker enforcement.
- No upstream call after failed authentication, validation, or quota reservation.
- Sanitised logs and generic error responses.

iOS automated tests must cover:

- New installation registration.
- Existing installation renewal.
- Session reuse before expiry.
- One renewal and one request retry after `401`, with no retry loop.
- Unsupported App Attest restricted fallback.
- Transient failure restricted fallback.
- Explicitly invalid proof does not silently downgrade.
- Base announcement/Apple speech fallback when proxy access fails.
- Invite UI is absent.
- No shared proxy token is required by a Release build.

Physical-device checks must cover:

- Clean Debug install using the development environment.
- Clean TestFlight install using the production environment.
- Relaunch after session storage.
- Session renewal after forced expiry.
- ElevenLabs preview and real announcement audio.
- Proxy unavailable and Apple service unavailable behaviour.
- Quota-exhausted messaging in Test Mode without rider-facing disruption.

## Acceptance Criteria

The work is complete when:

1. A clean TestFlight installation reaches the normal app without an invite, login, or manual secret.
2. The installation automatically establishes verified proxy access through production App Attest.
3. Facts and ElevenLabs speech work through a short-lived session without exposing upstream credentials.
4. Session renewal is automatic and survives app relaunch.
5. Unsupported or transiently blocked devices receive only the restricted fallback allowance.
6. Invalid attestations and replayed assertions are rejected and do not receive fallback access.
7. Per-installation, fallback, IP, and global controls prevent unbounded upstream consumption.
8. Apple App Review can use all reviewable features without contacting the developer for credentials.
9. The invite UI, invite endpoints, and invite-specific application code are removed.
10. Release builds contain no permanent shared proxy token or upstream API key.
11. Automated backend and iOS tests pass, the app builds for the physical device, and a clean TestFlight end-to-end test passes.
12. Logs, database rows, docs, source, build settings, and test fixtures contain no plaintext secrets or session tokens.

## Rollback

If verified provisioning fails after deployment:

- Keep names-only announcements and Apple speech working.
- Temporarily enable only the restricted fallback tier with a low global ceiling.
- Do not restore the invite gate or ship a shared permanent app token.
- Roll back the app/proxy code to the last compatible build while preserving additive database migrations.
- Diagnose using bounded failure categories and request IDs without exposing credential or location material.

## References

- Apple, Establishing your app's integrity: https://developer.apple.com/documentation/DeviceCheck/establishing-your-app-s-integrity
- Apple, Validating apps that connect to your server: https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
- Apple, Preparing to use the App Attest service: https://developer.apple.com/documentation/DeviceCheck/preparing-to-use-the-app-attest-service
- Project secret-management SOP: https://www.notion.so/320a4c502b1781d9ab34c4abf6d44152
- Current proxy contract: `FACT_PROXY_OPENAPI.yaml` and `FACT_PROXY_CONTRACT.md`
- Current reliability record: `ELEVENLABS_RELIABILITY_PLAN.md`

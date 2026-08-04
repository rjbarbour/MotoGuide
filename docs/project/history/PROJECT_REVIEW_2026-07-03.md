# RideHorizon Project Review

Date: 2026-07-03

Reviewer: Claude (high-to-medium level review, all components, not line-by-line).

Scope reviewed: iOS app (`repo/RideHorizon`), fact proxy (`repo/fact-proxy` and the stale top-level `fact-proxy`), MiroFish validation clone, workspace docs, and CI/workflow.

## Overall Verdict

This is a well-run MVP validation project. Separation of concerns across the workspace is sound: iOS client → thin LLM proxy → OpenAI/ElevenLabs, with MiroFish as an offline market-validation tool. Documentation discipline is strong, and the security posture is above par for a single-user prototype.

The main risks are not in the code. They are in workspace hygiene: a stale duplicate of the proxy that `dev.sh` still builds, substantial uncommitted work in both git repos on the eve of the field trial, and local-only modifications to a third-party clone that cannot currently be pushed anywhere.

## Component Summaries

### iOS app (`repo/RideHorizon`)

- Roughly 2,700 lines of Swift plus roughly 1,400 lines of tests.
- Pure logic is nicely extracted and tested: `AnnouncementPolicy`, `AnnouncementDecision`, `Address`, `FactPhraseBuilder`, `FirstRunState`, and the route fixture all have real unit coverage.
- Weak point: `LocationManager.swift` is now over 1,000 lines and is a god object. It owns location, geocoding, two speech engines (Apple and proxy ElevenLabs), audio-session management, interruption/resume logic, the announcement queue, voice selection, and about a dozen `UserDefaults`-backed settings. Only the fact generator is injectable, so most of that behaviour is untestable without a device.
- `ContentView.swift` is a similar 700-line monolith.
- The legacy `AnnouncementDecision` / `speakAfterEveryGeocode` debug path lives alongside the newer `AnnouncementPolicy` path, adding drift risk.
- Acceptable for a pre-field-trial MVP, but these two files are the natural target for the next refactor: extract a speech/audio coordinator and a settings store.

### Fact proxy (`repo/fact-proxy`)

- Spring Boot on Java 25, deployed to Fly.io.
- More mature than the "minimal MVP proxy" label in its README suggests:
  - Constant-time-style token comparison via `AuthUtils`.
  - Optional device-ID binding with an allowlist.
  - Bounded per-identity rate limiting.
  - Admin endpoints guarded by a separate token that returns 404 when unconfigured.
  - Prompt-injection hardening in the system prompt.
  - Output sanitisation on both server and client.
  - Remote prompt overrides for tuning fact quality without redeploying.
- Test coverage is solid (roughly 1,100 lines).
- The shared-single-token model is fine for one rider and is honestly documented as needing per-rider auth before wider distribution.

### MiroFish (`MiroFish`)

- A clone of the third-party `666ghj/MiroFish` social-simulation tool, used to run market-validation simulations for RideHorizon (documented in `API_RUNBOOK.md` and `docs/product/strategy/BUSINESS_VALIDATION_PLAN.md`).
- Sensible use of an off-the-shelf tool.
- Secrets handling (runtime `secret_resolver.py`, `.env` gitignored) follows the project SOP.

### Docs and workflow

- AGENTS.md routing (workspace file → repo file), milestone plans, roadmap-status ledger, OpenAPI contract with a human-readable companion, and status files are all coherent and cross-referenced.
- `dev.sh` is a good pattern.
- CI exists only for the proxy (deploy-on-push to Fly via Terraform). There is no iOS CI, which is a reasonable choice at this stage.

## Findings, Most Important First

### 1. `dev.sh` builds the wrong fact-proxy

The top-level `fact-proxy/` is a stale, untracked copy. The live one is `repo/fact-proxy`, which has since gained ElevenLabs speech, device binding, fact modes, place hierarchy, and prompt overrides. `dev.sh` (line 7) points `PROXY` at the stale copy, so `./dev.sh proxy build|run|smoke` builds and runs an obsolete service. The smoke test's request body (no `factMode`, no `placeHierarchy`) would be rejected by the current API anyway.

Fix: delete the top-level copy and repoint `dev.sh`, or make it an explicit symlink to `repo/fact-proxy`.

### 2. MiroFish local work has no home

Roughly 13 modified files plus new ones (`domain_presets.py`, `secret_resolver.py`, the runbook, validation scripts, reports) are uncommitted, and `origin` is the upstream `666ghj/MiroFish` repo that cannot be pushed to. A disk failure loses all of it.

Fix: fork it (or create a private repo), add that as a remote, commit to a branch, and push.

### 3. Uncommitted work in the main repo on `main`

Code changes (`LocationManager.swift`, `FactMode.java`, `OpenAiService.java`), several planning docs, and the whole `fact-quality/`, `prompt-overrides/`, and `scripts/` directories are sitting untracked or modified on the eve of the field trial.

Fix: commit before the ride so the trial result maps to a known revision. Note the coupling risk: a push touching `fact-proxy/**` on `main` auto-deploys to production, so uncommitted proxy changes and the deploy trigger are easy to trip over together.

### 4. Client/server timeout mismatch

The iOS client gives proxy calls 3 seconds (`ProxyFactGenerator.swift`, via `FactProxyContract.iosTimeoutSeconds`) while the proxy gives OpenAI 15 seconds (`OpenAiService.java`, line 92). Any generation slower than roughly 3 s is abandoned by the phone but still completes (and is paid for) on the server, and nothing caches the result. The graceful fallback to the base phrase is correct for ride safety, but expect a meaningful fraction of Short Facts to silently degrade to names-only on slow mobile networks.

Fix: log the timeout rate during the field trial before tuning either value.

### 5. CI deploys without running the test suite

`fact-proxy-deploy.yml` goes straight to Terraform plus `flyctl deploy`; `./gradlew test` never runs in CI. Add a test step before deploy.

Two smaller CI/doc drifts:

- The README documents the default model as `gpt-4o-mini` while CI pins `gpt-5.4-nano-2026-03-17`.
- The secrets-sync step never sets `ELEVENLABS_API_KEY`, so `/v1/speech` only works because it was presumably set manually via `fly secrets`. This is undocumented state that a redeploy from scratch would miss.

### 6. Duplicated planning docs

Both `MILESTONES.md` (workspace root) and `repo/MILESTONES.md` exist, and the repo one has uncommitted edits, despite the workspace AGENTS.md's own rule against duplicating long-lived content at workspace level. The top-level copy also predates M5.5/M6.5 in the roadmap ledger.

Fix: reduce the top-level file to a pointer, as was already done for AGENTS.md.

## What Is in Good Shape

- Secrets handling end-to-end: API keys server-side only, device Keychain for the proxy token, gitignored `.env` files, runtime resolution in MiroFish.
- Announcement safety model: boundary priority, cooldown, single-slot queue, yield-to-primary-audio, quiet mode.
- The OpenAPI contract kept as source of truth, with client and server both referencing it.
- Test coverage of pure logic on both platforms.
- Roadmap and status ledger discipline. ROADMAP_STATUS claims were checked against the sources and hold.

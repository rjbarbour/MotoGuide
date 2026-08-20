# RideHorizon Context

Last reviewed: 2026-08-20

## Project entry point

RideHorizon is a Rob-owned iOS product and follows AXON and the project instructions in `AGENTS.md`. Optimise for the enduring outcome and boundaries in `INTENT.md`, then select current work only from the Backlog.md CLI ledger.

Repository: `/Users/rob_dev/DocsLocal/motoguide/repo`

Research workspace: `/Users/rob_dev/DocsLocal/motoguide`

## Read order

1. `INTENT.md` — enduring purpose, user, boundaries and decision principles.
2. `AGENTS.md` — mandatory runtime constraints and procedure triggers.
3. `PROJECT.md` — last verified result, residual risks and current gate.
4. Backlog.md CLI — sole live delivery state; run `backlog instructions overview` before operating tasks.
5. `MILESTONES.md` — shallow product direction and capability sequence.
6. `docs/README.md` — route to relevant architecture, testing, operations, product or research records.

## Architecture summary

- `RideHorizon/` is the SwiftUI iPhone application.
- `RideHorizonTests/` and `RideHorizonUITests/` hold automated app evidence.
- `fact-proxy/` is the server-side fact and synthesised-speech proxy.
- `FACT_PROXY_OPENAPI.yaml` is the executable app-proxy contract.
- `privacy-site/` publishes the public privacy and support surface.
- `RideSessionController` owns ride and place-resolution sequencing.
- `AnnouncementCoordinator` owns boundary-to-speech sequencing.
- `RideHorizonApp` is the iOS composition root.

The app maintains a best-available place estimate from imperfect location and geocoding inputs. Navigation remains outside the product boundary.

## Authority map

| Concern | Canonical source |
| --- | --- |
| Enduring product purpose and boundaries | `INTENT.md` |
| Runtime constraints and procedure routing | `AGENTS.md` |
| Current verified state and decision gate | `PROJECT.md` |
| Live task status, scope, dependencies and evidence | Backlog.md CLI records under `backlog/` |
| Accepted project decisions | `backlog decision list --plain` and `backlog doc view doc-003 --plain` |
| Product direction and capability ladder | `MILESTONES.md` |
| Technical plans, contracts and ADRs | `docs/architecture/` |
| Test and release evidence rules | `docs/testing/` and `docs/operations/` |
| Research and market evidence | parent research workspace and `docs/research/` |

If sources conflict, stop the affected work and escalate instead of silently selecting a lower-authority source.

## Domain language

- **Ride session:** the explicit period in which RideHorizon owns location, place-resolution and announcement work.
- **Place estimate:** the best currently available geographic interpretation; never a guarantee of exact location.
- **Boundary:** a meaningful geographic level such as town, county, nation/region or country.
- **Fact:** selected or generated place-related information for the rider.
- **Announcement text:** rider-facing text prepared from a fact and place context.
- **Text-to-speech (TTS):** conversion of announcement text into speech.
- **Synthesised speech audio:** audio returned by the TTS provider; use **speech audio** as the short form.
- **Passive guide:** context-aware announcements that require no rider question.
- **Interactive guide:** later, explicitly bounded rider-initiated interaction.
- **Navigation hand-off:** passing a selected destination to a navigation app; RideHorizon does not calculate the route.

Canonical pipeline: **fact → announcement text → TTS → synthesised speech audio → playback**.

## Positive procedure triggers

| Trigger | Load completely before acting |
| --- | --- |
| Session start, resume, hand-off, compaction or material goal change | [SOP: AXON Context Bootstrap and Re-priming](https://app.notion.com/p/3c1a4c502b178138a716e5d078c92926) via the `axon-reprime` skill |
| Shape, claim, implement, review, integrate or complete delivery work | [SOP: Adaptive Agentic Software Delivery](https://app.notion.com/p/3aea4c502b1781a888b1f8e851697813) |
| Make substantive repository-file changes, or change branches, worktrees, PRs or integration state | [SOP: Tracked Work and Git Change Integration](https://app.notion.com/p/3b5a4c502b17815ea525d3c91dc65cf0) |
| Dirty, mixed, legacy or ambiguous repository state | [Draft SOP: Repository Hygiene Cleanup](https://app.notion.com/p/3b5a4c502b178117bbcbe330bb8467b4) |
| Build, archive, sign, upload or diagnose an iOS/TestFlight release | [SOP: iOS Build and TestFlight Deployment](https://app.notion.com/p/3b4a4c502b1781e18977d4e2d9b75c74) |
| Secrets, credentials, tokens, OAuth or environment-secret design | [SOP: Secret Management in Agentic AI Development](https://app.notion.com/p/320a4c502b1781d9ab34c4abf6d44152) |
| Any macOS Keychain credential operation | [SOP: macOS Keychain Credential Discovery and Access](https://app.notion.com/p/3aea4c502b17811bb795c545f601bd6f) |
| First authenticated GitHub or remote Git operation in a session | [GH-01 — GitHub Credential Profile Selection and PAT Use](https://app.notion.com/p/3baa4c502b1781c4a645c975b0393dd5) |

Detailed execution rules remain in `AGENTS.md` and the selected procedure; this file only routes them.

## Retrieval boundary

No Tier 3 retrieval collection is adopted for the coding repository. Use repository files and the Backlog.md CLI as implementation authority. Parent-workspace research is informative until an accepted outcome is transferred into this repository.

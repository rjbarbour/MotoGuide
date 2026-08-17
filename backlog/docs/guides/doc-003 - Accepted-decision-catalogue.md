---
id: doc-003
title: Accepted decision catalogue
type: guide
created_date: '2026-08-17 22:56'
updated_date: '2026-08-17 22:56'
tags:
  - decisions
  - guide
  - migration
---
# Accepted decision catalogue

## Purpose

Backlog.md v1.50.1 exposes only `decision create` and `decision list` through its supported public CLI. It does not expose a supported command for populating the generated Context, Decision and Consequences sections. The generated decision files therefore remain CLI-created index records and are not hand-edited.

This CLI-managed document holds the complete accepted decision content. Use `backlog decision list --plain` to discover decision IDs and `backlog doc view doc-003 --plain` for their substance. The former ledger remains available as doc-001 for detailed historical evidence.

## decision-001 — Adopt Backlog.md CLI as the sole live delivery ledger

### Context

RideHorizon used a manually maintained root ledger. The owner explicitly authorised adoption of the MrLesk Backlog.md CLI and retirement of the competing manual authority.

### Decision

Use the repository-backed Backlog.md CLI as the sole live delivery ledger. Keep configuration in `backlog.config.yml`, records under `backlog/`, and perform task, document and decision mutations only through supported public CLI commands.

### Consequences

The root `ITEM-BACKLOG.md` is retired after exact preservation as doc-001. One RH ID binds delivery work and Git evidence. Remote branch inspection remains enabled. Unsupported generated-record edits and undocumented browser or API mutation are prohibited.

## decision-002 — Map legacy letter-suffix task IDs to Backlog child IDs

### Context

The former ledger used letter suffixes that the CLI does not allocate as task IDs.

### Decision

Map RH-004A through RH-004G to RH-004.01 through RH-004.07, RH-013A to RH-013.01, and RH-019A to RH-019.01. RH-013B was only a prospective next-increment reference and does not become a false task. RH-037 remains a completed legacy identifier pointing to RH-053.

### Consequences

Historical identifiers remain traceable without fighting the supported ID model. Branches and documents should use the child ID and may include the legacy ID in parentheses where needed.

## decision-003 — Keep RH-024 Tier 1 as the next core RideHorizon increment

### Context

On 2026-08-17 the owner returned product direction to the core motorcycle experience and did not resume TestFlight evidence, release tooling or the family experiment.

### Decision

Nominate the bounded RH-024 Tier 1 sequence-aware fact slice as the next intended core increment. Confirm its live status through the CLI before claiming it.

### Consequences

This decision does not authorise implementation inside RH-056. RH-024 requires its own claim, branch, evidence and pull request. Later tiers and related prompt, memory or web-grounding work remain separately shaped.

## decision-004 — Keep the family-product experiment parked

### Context

The family-passenger framework, sequence and name research were preserved, but the owner chose to return attention to core RideHorizon.

### Decision

Do not advance the family experiment unless the owner explicitly resumes it.

### Consequences

The family material remains reference context only. Do not adopt Backseat Guider as a cleared name, involve an under-13 tester, or start family-priority tasks without reactivation and the existing data, compliance and evidence gates.

## decision-005 — Accept the temporary RH-019.01 disk-backed key-file exception with periodic review

### Context

The retained private-beta TestFlight tool uses short-lived mode-0600 disk-backed App Store Connect API key material. A RAM-backed alternative was considered but was not made an immediate merge prerequisite.

### Decision

Accept this narrow temporary exception for the retained private-beta workflow and keep the residual risk outstanding for periodic review.

### Consequences

The decision does not authorise a TestFlight upload and does not establish the exception as the permanent production design. Review it before wider distribution, after runner or custody changes, after cleanup failure or suspected exposure, and at release-tooling milestone health gates.

## decision-006 — Keep RH-002 exact-build confirmation and release evidence parked

### Context

Physical results must be attributed to the exact installed TestFlight build, but release work is not the current product direction.

### Decision

Do not act on the RH-002 exact-build confirmation or release evidence gate until TestFlight release work is deliberately resumed.

### Consequences

When resumed, confirm the installed build in RideHorizon Settings while stopped before attributing stationary or road results to it. The parked gate is operational evidence, not a new product choice.

# RideHorizon documentation index

This directory contains durable supporting documentation for the private RideHorizon repository. It is organised by purpose, not by the order in which documents were created.

## Reading order

1. Read `../AGENTS.md` for mandatory project rules.
2. Read `../PROJECT.md` for the last verified state and current gate.
3. Read `../Backlog.md` for active work and its evidence contract.
4. Use the areas below for the decision, plan, research or operational record relevant to that work.

## Areas

| Area | Use it for | Primary contents |
| --- | --- | --- |
| `architecture/adr/` | Record hard-to-reverse technical decisions. | Architecture decision records. |
| `architecture/contracts/` | Explain human-readable service and API contracts. | Fact proxy contract. |
| `architecture/design/` | Define enduring technical or interaction design. | Location-screen design. |
| `architecture/plans/` | Plan and assess technical work. | Proxy access, audio, speech reliability and fallback plans. |
| `architecture/specs/` | Define bounded implementation specifications. | Speech intelligibility calibration specification. |
| `product/plans/` | Plan product increments and product changes. | MVP polish and rebranding plans. |
| `product/strategy/` | Record market-validation and product-strategy work. | Business validation, PMF review and validation sprint. |
| `operations/app-store/` | Prepare App Store Connect and public listing material. | Submission readiness, test information and attribution. |
| `operations/privacy/` | Record privacy requirements, audits and publication work. | Privacy audit and policy publishing plan. |
| `operations/testflight/` | Operate the private beta and retain test evidence. | Beta pack, field-test evidence and temporary proxy-access plan. |
| `research/` | Preserve dated, source-based investigation. | App Store, privacy, TestFlight and market diligence research. |
| `evidence/fact-quality/` | Preserve reviewed factual-output samples and findings. | Fact and fact-sequence quality reviews. |

## Placement rules

- Keep current project control at the repository root: `AGENTS.md`, `PROJECT.md`, `Backlog.md` and `MILESTONES.md`.
- Keep component instructions next to the component: for example, `fact-proxy/README.md` and `privacy-site/README.md`.
- Use ISO-8601 dates in names for time-bound research, evidence, audits and status records.
- Update an existing authoritative document rather than creating a parallel plan or status file.
- Use `architecture/adr/` for decisions that would be costly or surprising to reverse; do not bury them only in a plan.
- Do not put generated build output, credentials, personal ride data or transient notes in `docs/`.

## Scope and source of truth

The canonical code and documentation live in this repository. Workspace-level material outside this repository is not versioned here and must not be treated as authoritative without first being deliberately imported or linked.

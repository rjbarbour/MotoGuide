# Documentation Reconciliation Plan

**Status:** Shaping  
**Date:** 2026-08-10  
**Backlog:** RH-034

## 1. Bottom line

Build documentation reconciliation as a **risk-scaled audit pipeline**, not as an unconditional nightly whole-repository LLM review.

The preferred design is:

1. run deterministic documentation checks and compute a weighted change profile;
2. select a review depth from that profile, with high-risk file classes able to override raw diff size;
3. use Codex only for the semantic reconciliation that deterministic checks cannot do;
4. keep clean runs ephemeral;
5. surface material findings in GitHub and propose fixes through reviewable changes rather than silently rewriting canonical documents.

The first implementation should be report-only. Automatic fixes should be introduced only after the review policy has accumulated enough evidence to distinguish safe mechanical corrections from authority or intent conflicts.

## 2. Problem

RideHorizon has several documentation classes that can drift independently:

- project orientation and runtime instructions;
- project state and delivery ledger;
- architecture plans, ADRs, contracts, designs and specifications;
- product plans, strategy and reference material;
- operational procedures and release evidence;
- implementation, configuration and tests that may invalidate documentation without modifying Markdown.

The repository already has explicit placement rules and canonical control files. The failure mode is therefore not simply missing documentation. It is **semantic drift**: stale claims, competing authorities, duplicated material, misplaced information, obsolete examples, missing routes, or implementation changes that invalidate previously correct documentation.

A full semantic scan after every small change would waste time and model budget. A pure deterministic linter cannot detect most semantic inconsistencies. The reconciliation system should spend reasoning effort in proportion to the amount and *kind* of change.

## 3. Objectives

The system should:

- detect structural documentation defects cheaply and deterministically;
- identify when a code or configuration change plausibly invalidates documentation;
- detect contradictions between canonical and supporting documents;
- detect stale, redundant or misplaced documentation;
- verify that canonical concerns still have one clear home;
- distinguish a stale lower-authority document from a genuine source-of-truth conflict;
- scale semantic review depth to repository change;
- produce concise, evidence-backed findings;
- avoid creating a new stream of nightly report files in the repository;
- never silently resolve product intent, governance or authority conflicts;
- be reusable as a pattern for other repositories after it proves useful in RideHorizon.

## 4. Non-goals

The first implementation will not:

- rewrite documentation automatically;
- turn the README into the project specification;
- infer new product intent from implementation drift;
- regenerate all documentation after each merge;
- maintain embeddings or a vector database;
- require a permanent external documentation SaaS;
- make line count the sole measure of review depth;
- block delivery on subjective style preferences;
- create a dated reconciliation report in Git for every run.

## 5. Authority model

The reconciler must use an explicit authority order rather than treating all prose as equally valid.

For RideHorizon, begin with the repository's existing control model:

1. applicable project and agent instructions;
2. owner-approved intent, decisions, specifications and contracts;
3. shipped interfaces, tests and operational configuration;
4. current delivery state in the Backlog.md CLI records and `PROJECT.md` according to their declared roles;
5. maintained supporting documentation;
6. research, history and evidence records;
7. filenames or inferred structure.

When two controlling sources conflict, the result is **CONFLICTED**, not an invitation for the agent to choose the more plausible wording.

## 6. Architecture

### 6.1 Stage A — deterministic repository profiler

A small repository-local tool should compare a base revision with the current revision and emit a machine-readable change profile, preferably JSON.

Collect at least:

- files added, removed, renamed and modified;
- insertions and deletions;
- documentation files changed;
- source files changed;
- tests changed;
- configuration, schema, API-contract and infrastructure files changed;
- top-level or canonical control files changed;
- directories/subsystems touched;
- relative links added or removed;
- headings added or removed from Markdown;
- likely document moves or duplications;
- age since the last full reconciliation;
- commits since the last successful reconciliation.

Do **not** use a single `lines_changed` threshold as the policy. A six-line OpenAPI change may justify more documentation review than a 1,000-line test-fixture update.

### 6.2 Stage B — deterministic documentation checks

Run these before any model call:

- Markdown parsing / heading hierarchy;
- local relative-link validation;
- required canonical files and allowed placement;
- duplicate or conflicting canonical filenames where rules can be expressed mechanically;
- stale routes from index files to missing targets;
- `git diff --check`;
- optional terminology/style checks where they have stable value;
- secret-pattern checks appropriate to documentation.

Failures become inputs to the semantic review rather than forcing the model to rediscover them.

### 6.3 Stage C — review-depth classifier

Use deterministic thresholds plus escalation rules.

Recommended initial policy:

| Level | Default trigger | Semantic scope | Output |
| --- | --- | --- | --- |
| **R0 — structural only** | Tiny low-risk change; no docs or documentation-sensitive paths changed | None | CI/check summary only |
| **R1 — targeted** | Small change or any ordinary documentation edit | Changed docs plus directly mapped implementation/authority sources | Findings only |
| **R2 — subsystem** | Moderate cross-file change or a documentation-sensitive contract/architecture change | Affected subsystem, its docs, canonical routes and immediate neighbours | Findings plus proposed dispositions |
| **R3 — repository reconciliation** | Large/refactoring change, multiple canonical concerns touched, explicit trigger, or periodic full audit | Entire documentation map and principal implementation authorities | Full reconciliation summary |

Initial quantitative defaults:

- **R0:** at most 5 changed files and at most 100 non-documentation changed lines, with no escalation trigger;
- **R1:** up to 15 files / 500 non-documentation changed lines, or any ordinary Markdown change, with no R2/R3 trigger;
- **R2:** 16–40 files, 501–2,000 non-documentation changed lines, more than one subsystem, or any R2 escalation trigger;
- **R3:** more than 40 files, more than 2,000 non-documentation changed lines, broad rename/restructure, multiple canonical concerns, or the periodic full-audit trigger.

These numbers are starting priors, not eternal policy. Tune them from observed false positives, missed drift and review cost.

### 6.4 Escalation rules

Escalation rules override raw diff size.

At minimum, escalate to **R1** when any maintained documentation changes.

Escalate to at least **R2** when a change touches:

- `README.md`, `AGENTS.md`, `PROJECT.md`, `backlog.config.yml`, CLI-managed `backlog/` records or `MILESTONES.md` in a way that changes claims or routing;
- an ADR, architecture contract or bounded specification;
- public API or OpenAPI contracts;
- persistent settings keys, migrations or schemas;
- release/deployment configuration;
- security, privacy, permissions, authentication or secrets handling;
- external-provider behaviour documented elsewhere;
- a file move/rename likely to invalidate documentation routes;
- a feature or subsystem whose documentation map declares coupled artefacts.

Escalate to **R3** when:

- repository structure or documentation taxonomy changes;
- a major refactor crosses several subsystems;
- more than one canonical source appears to change ownership of the same concern;
- the previous full reconciliation is older than the configured maximum interval;
- an R2 run reports possible cross-repository or systemic drift.

## 7. Documentation-impact map

Introduce a small machine-readable policy file during implementation, for example `.github/documentation-policy.yml`.

It should describe **relationships, not prose**. Example concepts:

```yaml
canonical:
  README.md: orientation
  AGENTS.md: runtime-instructions
  PROJECT.md: verified-project-state
  backlog/: delivery-ledger

impact_rules:
  - paths:
      - RideHorizon/ProxyFactGenerator.swift
      - FACT_PROXY_OPENAPI.yaml
      - fact-proxy/**
    review:
      - docs/architecture/contracts/FACT_PROXY_CONTRACT.md
      - docs/architecture/plans/APP_ATTEST_PROXY_ACCESS_PLAN.md

  - paths:
      - RideHorizon/LocationManager.swift
      - RideHorizon/AnnouncementPolicy.swift
    review:
      - docs/architecture/design/**
      - MILESTONES.md
```

Do not attempt to map every source file manually. Start with high-value architectural seams and canonical documentation, then extend only where missed drift demonstrates value.

## 8. Semantic reconciliation contract

The Codex review should answer bounded questions and return structured findings.

For each assessed concern, classify it as:

- **ALIGNED** — material claims agree;
- **STALE** — a lower-authority source is demonstrably outdated;
- **CONFLICTED** — controlling sources disagree;
- **REDUNDANT** — substantive content is duplicated without a useful projection distinction;
- **MISPLACED** — the content belongs to another declared canonical concern or documentation area;
- **MISSING** — a required route or document is absent;
- **UNVERIFIED** — insufficient evidence to decide.

Each non-ALIGNED finding should include:

- finding ID;
- severity;
- confidence;
- concern;
- affected paths;
- controlling authority;
- concise evidence;
- recommended disposition;
- whether a mechanical fix is safe to propose;
- whether owner judgement is required.

Example:

```text
DOC-017  HIGH  STALE
Concern: proxy endpoint contract
Canonical authority: FACT_PROXY_OPENAPI.yaml
Affected: docs/architecture/contracts/FACT_PROXY_CONTRACT.md
Evidence: documented response category no longer exists in the current contract
Disposition: update supporting contract
Safe to propose automatically: yes
Owner decision required: no
```

## 9. Execution policy

### Pull requests / merges

Run Stage A and Stage B on every relevant PR or merge.

- R0 stops after deterministic checks.
- R1/R2 runs the bounded Codex semantic review.
- A finding that indicates possible systemic drift may escalate the same run or schedule a full R3 review.

### Scheduled review

Use a scheduled GitHub workflow as a safety net, but **do not force a full semantic review every night**.

Recommended schedule:

- nightly: calculate the change profile since the last successful semantic reconciliation;
- if accumulated change remains below R1, record success without a model call;
- if thresholds reach R1/R2, run that review level;
- weekly: force R3 while the repository is actively changing;
- later, reduce the forced R3 cadence if evidence shows incremental review reliably catches drift.

This gives the desired nightly assurance while avoiding pointless whole-repository rereads on quiet days.

## 10. Reporting and persistence

Avoid committing reconciliation reports to the repository by default. They would become another documentation stream requiring maintenance.

Preferred outputs:

1. GitHub Actions job summary for every executed review;
2. structured JSON as a short-retention workflow artifact for diagnosis and trend analysis;
3. no issue or PR for a clean run;
4. one open/updatable documentation-reconciliation issue for unresolved material findings, rather than one issue per night;
5. draft PR only for a bounded set of high-confidence fixes.

Persist only durable decisions or accepted corrections back into canonical documentation.

## 11. Automatic-fix policy

### Initially allowed

None. Phase 1 is report-only.

### Later safe-to-propose class

After evidence from real runs, allow draft-PR proposals for high-confidence mechanical fixes such as:

- broken relative links;
- renamed file references;
- clearly stale commands when the executable source is authoritative;
- duplicated routes/index entries;
- purely mechanical terminology corrections governed by a stable rule.

### Never auto-resolve without explicit policy

- product purpose or scope;
- competing canonical authorities;
- architectural decisions;
- roadmap or delivery status;
- privacy/security intent;
- legal or App Store declarations;
- deletion of apparently redundant documentation where distinct historical/evidence value may exist.

## 12. Implementation stages

### Phase 1 — Baseline and report-only prototype

Goal: prove the review rubric before automating repository writes.

1. Define `.github/documentation-policy.yml` with canonical roles, high-value impact mappings and escalation paths.
2. Implement the deterministic change-profiler script.
3. Add deterministic Markdown/link/placement checks using existing tools where practical.
4. Create the Codex reconciliation instruction/skill.
5. Run several historical commit ranges through R0–R3 manually or in a non-blocking workflow.
6. Record false positives, missed drift, cost and review duration.
7. Tune thresholds without weakening high-risk escalation rules.

Exit gate: the same commit range produces stable review classification and materially useful findings in repeated independent runs.

### Phase 2 — PR/merge integration

Goal: catch documentation drift close to the change that caused it.

1. Run profiler and deterministic checks on PRs.
2. Invoke Codex only for R1+.
3. Post concise findings to the check/job summary.
4. Keep the workflow advisory initially.
5. Promote only deterministic failures with low ambiguity to blocking status.

Exit gate: normal PRs do not produce excessive noise and known documentation-sensitive changes trigger the expected scope.

### Phase 3 — Nightly accumulation and periodic full reconciliation

Goal: detect drift that PR-local review misses.

1. Schedule nightly evaluation of accumulated change since the last semantic reconciliation.
2. Skip the model call below threshold.
3. Run R1/R2 when accumulated change justifies it.
4. Force a weekly R3 during active development.
5. Update one reconciliation issue only when unresolved findings exist.

Exit gate: several weeks of operation show useful findings without daily report churn or frequent unnecessary R3 scans.

### Phase 4 — Reviewed fix proposals

Goal: automate toil without delegating authority.

1. Define the mechanical-safe fix class from Phase 1–3 evidence.
2. Allow Codex to prepare draft PRs only for that class.
3. Require normal review and deterministic checks before merge.
4. Measure reverted/edited proposals; narrow the class if correction rates are poor.

Exit gate: automatic proposals are routinely accepted with little or no human correction and have not crossed authority boundaries.

## 13. Suggested implementation stack

Preferred:

- Git for change statistics and rename detection;
- repository-local script for weighted classification;
- existing Markdown/link tools for deterministic checks;
- GitHub Actions for execution and persistence of check state;
- GitHub Agentic Workflows or a direct Codex GitHub Action for semantic reconciliation;
- Codex Desktop only as the development bench for tuning the skill/rubric.

The repository should own the policy and prompts needed to reproduce a review. The laptop should not be the long-term scheduler.

## 14. Initial success measures

Track these for the first 20–30 semantic reviews:

- percentage of runs by R0/R1/R2/R3;
- model calls avoided by R0;
- findings accepted as real;
- false-positive findings;
- material drift later found manually that the system missed;
- percentage of findings caused by missing impact mappings;
- average findings per semantic run;
- draft-fix acceptance rate once Phase 4 begins.

A useful system should make R0/R1 the common case. If most changes escalate to R3, the policy is too coarse or the documentation architecture is too coupled.

## 15. Appendix A — Alternatives considered

### A. Full nightly Codex review

**Advantages:** simplest mental model; broad coverage.  
**Disadvantages:** repeated cost, repeated context loading, noisy reports, and little relationship between review effort and actual repository change.  
**Decision:** reject as the default; retain periodic R3 as a backstop.

### B. Codex Desktop scheduled task

**Advantages:** very fast to prototype; can use the local checkout and project skills.  
**Disadvantages:** depends on the local machine/app being available and is a poor durable project control plane.  
**Decision:** use for rubric development if convenient, not as the production scheduler.

### C. Plain GitHub Action invoking Codex directly

**Advantages:** explicit, conventional CI, minimal abstraction.  
**Disadvantages:** more orchestration, permissions and reporting code to own.  
**Decision:** valid fallback if GitHub Agentic Workflows proves immature or constraining.

### D. GitHub Agentic Workflows

**Advantages:** schedule/event orchestration, Codex engine support and review-oriented safe outputs align with the problem.  
**Disadvantages:** another framework layer and still relatively new.  
**Decision:** preferred production experiment after the report-only rubric is stable.

### E. Documentation SaaS / hosted knowledge platform

**Advantages:** may provide link checking, search and content lifecycle features.  
**Disadvantages:** weak fit for repository-specific authority semantics, external dependency and likely duplicate source-of-truth concerns.  
**Decision:** do not introduce for this problem unless the repository-local approach exposes a specific missing capability.

### F. Semantic embeddings / repository knowledge graph

**Advantages:** potentially better discovery of weakly linked duplicate or related material at large scale.  
**Disadvantages:** premature complexity for this repository; retrieval infrastructure can itself drift.  
**Decision:** defer until simple path mapping plus agentic repository search produces demonstrated misses.

## 16. Appendix B — Threshold tuning principle

Treat quantitative thresholds as a **cost-control heuristic**, not as risk truth.

The policy is:

> Diff magnitude sets the default review level; semantic sensitivity can only escalate it.

Never allow a small diff to suppress review of a change to a high-authority contract, security/privacy boundary, schema, public interface or canonical documentation source.

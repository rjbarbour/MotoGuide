# RH-056 Backlog CLI Migration Continuation and Evidence — 2026-08-17

## Purpose

This record preserved the verified continuation state for the migration from the manual `ITEM-BACKLOG.md` ledger to MrLesk Backlog.md CLI. Sections labelled as checkpoint or pre-compaction evidence describe the intentionally incomplete state at that time. The completion reconciliation below records the later authority switch; do not use the checkpoint inventory as current delivery status.

The owner requested this migration after RH-055 returned delivery focus to the core RideHorizon product. The requested outcome is to adopt the same Backlog.md CLI operating model used in other projects, retire `ITEM-BACKLOG.md`, and maintain repository hygiene. This is a documentation and control-plane task only. It must not change app, proxy, TestFlight or credential behaviour, and it does not merge or modify RH-019A.

## Completion reconciliation — 2026-08-17

- The former ledger and CLI-managed `doc-001` compared byte-for-byte before the root ledger was retired.
- The CLI inventory contains 65 tasks: RH-001 through RH-056 plus nine mapped children. `doc-002` records every suffix mapping and explains why legacy RH-013B did not become a false task.
- RH-024 is the only task labelled `ready`; RH-056 is the only task in progress during migration; RH-002, RH-019.01 and the family-product stream remain explicitly parked.
- Six accepted decision records preserve the ledger adoption, suffix mapping, core focus, parked family experiment, temporary RH-019.01 exception and parked RH-002 evidence gate.
- `AGENTS.md`, `README.md`, `PROJECT.md`, `MILESTONES.md` and affected supporting documents route current delivery state to Backlog.md CLI records.
- `remoteOperations` is true. An authenticated fetch through the verified GH-PERSONAL process-local PAT route confirmed `origin/main` at `bca9556` and the RH-019.01 recovery worktree clean at `ee4686d`.
- No app, proxy, TestFlight or credential behaviour changed. No iOS build or app test was run because this is a documentation and control-plane migration.
- Publication, pull-request integration and post-merge cleanup remain the final Git integration boundary; use RH-056 and Git history rather than this record for live status.

## Verified checkpoint repository state

Verified locally on 2026-08-17:

| Checkout | Branch | Commit | State |
|---|---|---|---|
| `/Users/rob_dev/DocsLocal/motoguide/repo` | `codex/rh-056-adopt-backlog-cli` | `5a1bfd6` | Active migration branch. Tracked files are checkpoint-clean; `backlog.config.yml` and `backlog/` are untracked migration output. |
| `/Users/rob_dev/DocsLocal/motoguide/rh-019a-testflight-tooling` | `codex/rh-019a-testflight-tooling-recovery` | `ee4686d` | Clean, published retained WIP. Do not alter as part of RH-056. |
| `main` / `origin/main` | — | `bca9556` | RH-055 integrated through PR 22 before RH-056 began. |

The active branch has one checkpoint commit:

- `5a1bfd6 docs(RH-056): claim Backlog CLI migration`

Immediately before this continuation record was added, `git status --short` in the canonical checkout was exactly:

```text
?? backlog.config.yml
?? backlog/
```

## Governing decisions and rationale

- Use MrLesk Backlog.md CLI as the sole live Git-backed delivery ledger.
- Preserve the former ledger byte-for-byte as a discoverable CLI-managed historical document before retirement.
- Recreate live task records through supported public CLI commands. Do not hand-edit generated task or document records.
- Preserve the established `RH` prefix and use three-digit top-level IDs.
- Map legacy letter suffixes to CLI-supported child IDs and document the mapping. Examples already selected are `RH-004A` to `RH-004.01` and `RH-019A` to `RH-019.01`.
- Keep remote operations enabled so task/branch hygiene checks remain available.
- Remove `ITEM-BACKLOG.md` only after migration completeness, status mapping, routing and CLI verification pass.
- No iOS build or app/proxy test suite is warranted for this Markdown/configuration-only migration.

The relevant adoption SOP required historical preservation, public CLI mutation, deliberate status migration, project-routing updates and verification before deletion. Adaptive Delivery v1.6 and Tracked Work and Git Integration v0.6 also apply. The repository-hygiene SOP encountered during the session was a draft and was treated as informative; the adoption and Git SOPs control this work.

The user explicitly requested learning from earlier migrations through Session Vault. Both semantic and exact supported searches failed with `Unable to connect`. The Session Vault skill prohibited bypassing that failure by parsing vault storage directly. The migration therefore used the current SOP and locally indexed lessons from the prior AI-course migration: preserve the ledger as a historical document, keep `remoteOperations` enabled, use supported CLI mutation only, and explicitly map non-numeric suffixes. Retry the supported Session Vault search when the connector is available, but do not block safe mechanical migration work solely on that outage.

## Work completed before compaction

1. RH-056 was recorded in `ITEM-BACKLOG.md` and claimed on `codex/rh-056-adopt-backlog-cli`; commit `5a1bfd6` is the clean recovery point.
2. Backlog.md configuration was initialised at `/Users/rob_dev/DocsLocal/motoguide/repo/backlog.config.yml` with:
   - project name `RideHorizon`;
   - task prefix `RH`;
   - three-digit IDs;
   - statuses `To Do`, `In Progress`, and `Done`;
   - `remote_operations: true`;
   - `auto_commit: false`;
   - backlog directory `backlog`.
3. The complete former ledger was preserved as `/Users/rob_dev/DocsLocal/motoguide/repo/backlog/docs/history/doc-001 - 2026-08-17-migration-from-ITEM-BACKLOG.md.md`. Its front matter identifies it as `doc-001`; its body begins with the original `# RideHorizon Delivery Ledger` content.
4. Task creation began in numeric order. There are currently 21 generated task files: `RH-001` through `RH-013`, plus child tasks `RH-004.01` through `RH-004.07` and `RH-013.01`.

This is only partial migration evidence. Tasks after RH-013 and any remaining child/letter-suffix records have not yet been shown as created. Status fidelity, task content completeness, decisions, routing-document changes, removal of `ITEM-BACKLOG.md`, independent review, commit, publication and integration are still outstanding.

## Historical continuation sequence

1. Inspect `ITEM-BACKLOG.md` and enumerate every defined task and legacy suffix before creating more records. Compare that inventory with `backlog task list --json`; do not infer completeness from filenames alone.
2. Continue creating missing tasks through the public Backlog.md CLI in established numeric order. Preserve stable IDs wherever supported and record every suffix mapping in the migration documentation.
3. Migrate each task's intended status deliberately. RH-024 Tier 1 must remain the single Ready/core next increment in project meaning; RH-002 and the family experiment remain parked; RH-019A remains accepted-but-parked operational tooling until separately resumed.
4. Reconcile `AGENTS.md`, `README.md`, `PROJECT.md` and `MILESTONES.md` so they route agents to Backlog.md CLI and `backlog/`, and no longer identify `ITEM-BACKLOG.md` as canonical. Avoid duplicating live task status in narrative documents.
5. Verify the historical document is complete and discoverable, then remove `ITEM-BACKLOG.md` as the final authority switch. Do not delete it earlier.
6. Run the deterministic CLI, link, diff and repository-hygiene checks below. Retry supported Session Vault search if available and incorporate any material migration lesson without reopening settled project decisions.
7. Obtain an independent completeness review of the final migration diff. Commit coherent recovery points, publish one RH-056 branch and integrate one documentation/control-plane pull request. Do not run an iOS build, Apple authentication or TestFlight operation.
8. After integration, fast-forward the canonical checkout and verify that only the clean RH-019A WIP branch/worktree remains alongside clean `main`.

## Verification commands

Run from `/Users/rob_dev/DocsLocal/motoguide/repo` unless a command contains an explicit path.

- `git status --short --branch` — expected during migration: branch `codex/rh-056-adopt-backlog-cli` plus only understood RH-056 documentation/configuration changes; expected at the final hand-off: clean branch state.
- `backlog task list --json` — expected result: parseable JSON covering every task inventoried from the former ledger with the intended IDs and statuses.
- `backlog doc list` — expected result: includes historical document `doc-001` for the 2026-08-17 `ITEM-BACKLOG.md` migration.
- `backlog decision list --json` — expected result: parseable JSON; reconcile any source decisions deliberately rather than silently dropping them.
- `backlog config get remoteOperations` — expected result: `true`.
- `test ! -e ITEM-BACKLOG.md` — run only after all preceding migration checks pass; expected result: no output and exit status 0.
- `git diff --check` — expected result: no output and exit status 0.
- `git diff --name-only main...HEAD` — expected result: control-plane Markdown/configuration paths only; no app, proxy, release-tool or credential files.
- `git -C /Users/rob_dev/DocsLocal/motoguide/rh-019a-testflight-tooling status --short --branch` — expected result: clean retained WIP aligned with `origin/codex/rh-019a-testflight-tooling-recovery`.

## Stop conditions

Stop before any of the following:

- deleting `ITEM-BACKLOG.md` without a complete task/status inventory and passing CLI verification;
- editing generated Backlog task/document files directly instead of using supported CLI mutation;
- renumbering an established task without an explicit recorded mapping;
- creating two competing live ledgers;
- modifying or merging RH-019A, resuming RH-002, or starting RH-024 implementation inside RH-056;
- changing runtime, release, credential or TestFlight behaviour;
- claiming the migration complete at the checkpoint while task creation remained at the then-current partial count of 21.

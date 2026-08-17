---
id: doc-002
title: Backlog.md workflow and migration mapping
type: guide
created_date: '2026-08-17 22:44'
updated_date: '2026-08-17 22:57'
tags:
  - guide
  - workflow
  - migration
---
# Backlog.md workflow and migration mapping

## Live authority

Backlog.md is the sole live delivery ledger for RideHorizon. The repository-backed records are under `backlog/` and the project configuration is `backlog.config.yml`.

Before creating, claiming, executing or closing work, run:

- `backlog instructions overview`
- the matching task-creation, task-execution or task-finalization guide named by the overview
- `backlog task list --plain` to inspect current work
- `backlog task view RH-XXX --plain` before changing a task

Use supported public `backlog` CLI commands for every task, document and decision mutation. Do not edit generated records directly. One RH work-item ID binds the task, branch, worktree, commits, pull request and evidence.

## Decision records

Backlog.md v1.50.1 provides supported public commands to create and list decisions, but not to populate or update their Context, Decision and Consequences sections. The generated decision files are therefore index stubs and must not be hand-edited.

Use `backlog decision list --plain` to discover decision IDs. Use `backlog doc view doc-003 --plain` for the complete accepted Context, Decision and Consequences. doc-001 retains the original historical evidence.

## Migration status mapping

- Legacy completed or integrated work maps to `Done`, with completion evidence preserved in doc-001.
- Legacy ready work maps to `To Do` plus the `ready` label.
- Legacy shaping work maps to `To Do` plus the `shaping` label.
- Parked work maps to `To Do` plus the `parked` label.
- Narrative project documents preserve dated direction and route live task state to the CLI rather than duplicating it.

## Legacy identifier mapping

Backlog.md child IDs replace unsupported letter suffixes:

- RH-004A to RH-004.01
- RH-004B to RH-004.02
- RH-004C to RH-004.03
- RH-004D to RH-004.04
- RH-004E to RH-004.05
- RH-004F to RH-004.06
- RH-004G to RH-004.07
- RH-013A to RH-013.01
- RH-019A to RH-019.01

RH-013B was a prospective next-increment reference, not a separately defined task, so it remains historical context in doc-001 rather than becoming a false live record. RH-037 is retained as a completed legacy identifier and points to RH-053, which contains the integrated packaged-build identity outcome.

## Preserved history

doc-001 contains the complete former `ITEM-BACKLOG.md` ledger as it stood at the authority switch on 2026-08-17. It preserves detailed historical scope, decisions, evidence and earlier status language. It is not a second live ledger.

## Project routing

Trello remains the intake surface. Accepted delivery work is represented here before implementation. Notion holds binding cross-project SOPs. `PROJECT.md` preserves dated verified product direction and points to the CLI for live status rather than duplicating the board.

## Terms

- A task is a tracked delivery record.
- Status shows workflow state.
- Acceptance criteria define the task-specific outcome.
- Definition of Done defines reusable completion checks where configured.
- The implementation plan records the approved execution route for started work.
- Notes contain execution evidence and exceptions.
- The final summary records the verified outcome when a task is completed.

# RideHorizon Intent

Status: Active

Last reviewed: 2026-08-20

## Purpose

RideHorizon restores the geographic context that turn-by-turn navigation omits. It helps a rider understand where they are, what kind of place they are travelling through and, when useful, why that place matters.

RideHorizon is an ambient place-awareness companion. It runs alongside a navigation app; it does not replace one.

## First user and canonical use case

The first user is a touring motorcyclist on a long ride, an international trip or unfamiliar roads. They use an iPhone and Bluetooth helmet headset while a separate navigation app owns the route.

During an active ride, RideHorizon maintains a best-available place estimate, displays the current geographic hierarchy and detects meaningful place or boundary changes. It may speak a short, sparse announcement without requiring the rider to look at or interact with the phone.

The visual Location experience is independently valuable. Audio is optional, secondary to safety-critical navigation and always controllable by the rider.

## MVP1 boundary

MVP1 is a UK-first private-beta learning tool that:

- runs during an explicit ride session;
- monitors GPS location and reverse-geocoded place context;
- displays the best-available current place and hierarchy;
- detects meaningful town or county changes;
- optionally speaks short announcements through helmet audio; and
- supports Names Only, Short Facts and Quiet modes.

MVP1 should prove real-ride feasibility, usefulness, trust and acceptable distraction. It is not the complete commercial proposition.

## Optional future direction

If evidence justifies expansion, RideHorizon may progress from visual awareness and sparse announcements to a passive contextual tour guide, then to bounded rider-initiated questions, nearby place suggestions and navigation hand-off. The rider controls frequency, length, topics and detail.

This direction is optional. It does not authorise always-listening audio, open-ended conversation while moving or route ownership.

## Non-goals

RideHorizon is not:

- a route planner or turn-by-turn navigation system;
- a social ride-tracking product;
- a general travel-planning assistant;
- an always-listening microphone experience;
- a source of riding, speed or safety instructions; or
- a commitment to car support, Europe-wide coverage or a full AI guide before the motorbike use case is validated.

## Decision principles

When goals conflict, prefer:

1. rider attention and safety over novelty or announcement frequency;
2. useful silence over weak, repetitive or stale content;
3. honest uncertainty over false location precision;
4. deterministic location and boundary behaviour before generated interpretation;
5. the visual core before optional audio richness;
6. existing navigation ownership over route duplication;
7. short, sparse and interruptible speech over completeness;
8. privacy-minimising context over unnecessary personal or precise-location data;
9. real-ride evidence over simulator plausibility; and
10. small reversible increments over speculative platform expansion.

## Change authority

This file is the durable product-intent authority. Change its purpose, first user, canonical use case, product boundary, non-goals or decision principles only with explicit owner approval. Current delivery state belongs in `PROJECT.md` and the Backlog.md CLI ledger.

## Source basis

- `AGENTS.md` — accepted project purpose, product definition and standing constraints.
- `MILESTONES.md` — capability ladder, MVP scope and product decisions.
- `docs/product/reference/HUMAN_MOTORCYCLE_TOUR_GUIDE_REFERENCE.md` — passive-guide reference model.
- `docs/product/reference/INTERACTIVE_TOUR_GUIDE_REFERENCE.md` — later interactive-guide boundary.
- RideHorizon ICB: `/Users/rob_dev/DocsLocal/digital-mercenaries-ltd/icb-catalogue/staged_icbs/6a1047a6a591ed37d9fd4e0e.md` — preserved upstream idea record.

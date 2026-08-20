# RideHorizon

RideHorizon is an iPhone geographic-awareness companion for motorcyclists. Its visual Location experience provides the core place context, with optional short audio announcements while the rider continues to use their normal navigation app.

## Start here

- [Project intent](INTENT.md): enduring purpose, user, boundaries and decision principles.
- [Project context](CONTEXT.md): canonical agent entry point, authority map and triggered resource routes.
- [Project state](PROJECT.md): the last verified state and the current decision gate.
- Backlog.md delivery ledger: run `backlog instructions overview`, then use `backlog task list --plain` and `backlog task view RH-XXX --plain`; repository-backed records live under `backlog/`.
- [Milestones](MILESTONES.md): the forward product plan.
- [Documentation index](docs/README.md): where every supporting record belongs and when to use it.
- [Agent instructions](AGENTS.md): mandatory operating rules for people and coding agents.

## Repository map

- `RideHorizon/`: iOS app source.
- `RideHorizonTests/` and `RideHorizonUITests/`: automated tests.
- `fact-proxy/`: server-side fact and speech proxy.
- `privacy-site/`: published privacy-policy site.
- `docs/`: product, architecture, operations, research and evidence records.
- `backlog/` and `backlog.config.yml`: CLI-managed delivery tasks, decisions, guides and preserved ledger history.

This is a private product repository. Do not add secrets, personal ride logs, location history or private notes.

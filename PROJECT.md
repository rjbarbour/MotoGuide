# RideHorizon Project State

Last verified: 2026-08-19

## Current product direction

The accepted decision recorded on 2026-08-18 establishes `m-1 — Core ride reliability and continuity` as the current product sequence. It supersedes the earlier nomination of sequence-aware facts as the next increment and puts reliable announcements while Google Maps is foregrounded first. This is dated product direction, not a duplicate assertion of live task status. Run `backlog task list --plain` and inspect the selected task through the CLI before claiming work.

## Last verified result

The High-priority architecture foundation and its workflow-boundary refinement are integrated through PR #39 at `243be88`. Production dependencies now enter through the composition root; `RideSessionController` owns ride and place-resolution sequencing; and `AnnouncementCoordinator` owns boundary-to-speech sequencing. The final branch passed 222 local simulator tests, 222 GitHub iOS tests, an unsigned Release build and zero-finding independent Standards and Specification reviews. Later Medium and Low architecture phases remain gated rather than automatically selected.

Build-output hygiene is integrated through PR #41 at `5834985`. Local Xcode output now uses one external, task-scoped DerivedData parent with completion cleanup and seven-day stale pruning; generated root/cache residue was removed, while legacy TestFlight archives and evidence were preserved outside the checkout.

The latest locally verified Internal TestFlight receipt is for RideHorizon `0.12.4 (20260806.221234)`. Its SHA-256-protected record reports `VALID`, permanently `INTERNAL_ONLY`, `IN_BETA_TESTING`, internal-group readiness and `ready_for_internal_tester`, using unchanged-input evidence from 182 passing simulator tests. The tester state does not prove which binary is installed on the phone. Exact Settings build confirmation and build-specific stationary/road evidence remain outstanding under the parked RH-002 item. The Settings build-identity feature is integrated; the RH-019.01 deployment tool remains preserved as parked WIP under an accepted temporary security exception. Do not treat the receipt as proof that current `main` can reproduce that historical binary.

The public support page now displays and links to `support@digitalmercenaries.ai`. Cloudflare Pages deployment `https://8511db66.ridehorizon-edge.pages.dev` and the canonical `https://ridehorizon.digitalmercenaries.ai/support` page were verified on 2026-08-04.

The on-device place model now retains the supported Apple placemark fields and displays supplied values in the expanded Location panel. `subLocality` is the current place label when Apple provides it, with `locality` retained as its enclosing place. The full simulator unit target and signed generic-iPhone Debug build passed on 2026-08-05; the phone was not connected for installation or live-response sampling.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, installation/launch of the current signed development candidate, and an exact processed Release archive exist. The archive has passed cloud-managed Apple Distribution signing, strict local verification, Apple server-side validation, upload and App Store Connect processing. TestFlight installation and the manual ride smoke test remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, bounded ride/audio lifecycles, provider fallback and green automated checks are in place. Stationary music interruption/restoration, Bluetooth, background-end and real-world battery evidence still define the release gate.

## Current gate

Delivery selection is controlled by the Backlog.md CLI. Decision-007 establishes the reliability-first sequence in `m-1 — Core ride reliability and continuity`; `RH-059 — Restore announcements while Google Maps is foregrounded` is the sole ready item after the High architecture close-out. It requires a separate physical-device diagnosis and has not been started. The Medium and Low architecture phases remain separate and gated.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly version 38 is configured with `min_machines_running = 1`; monitor availability and cost during the private-beta window, then deliberately decide whether to restore scale-to-zero.
- The 10-minute/two-minute background inactivity behaviour still needs physical evidence with the screen locked.
- Announcement-scoped interruption and restoration still need stationary music and Bluetooth-headset evidence; automated checks cannot assess subjective loudness or sudden perceived volume changes.
- iOS exposes audio-session events and output-volume snapshots, but not reliable external-app identity or control of system volume; coexistence still requires physical evidence.
- Background location, battery and Bluetooth behaviour require evidence from the exact replacement TestFlight build and real rides.
- Apple may omit or vary sub-locality, areas-of-interest and Apple-region labels by coordinate, locale, map-data version and iOS version. The app now exposes those responses, but a real-device sample is still required before asserting resolution for Hersham, Weybridge, Claygate, Surbiton, Seething Wells or any protected-landscape boundary.
- RH-019.01 (legacy RH-019A) temporarily accepts short-lived mode-`0600` disk-backed App Store Connect key material for the private-beta tool. Review the exception before wider distribution, after any runner or custody change, after a cleanup failure or suspected exposure, and at release-tooling milestone health gates.

## Next outcomes

1. Confirm the selected work item and programme through the Backlog.md CLI and claim only that task.
2. Evaluate its bounded behaviour independently, then return to the applicable milestone health gate before selecting further work.

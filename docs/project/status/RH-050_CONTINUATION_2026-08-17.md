# RH-050 Preservation-Stream Closeout — 2026-08-17

## Outcome

RH-045 commit `2a1a31e` was used only as a read-only source shelf. It was never merged or rebased as a whole. Every useful stream was transferred to a task branch created from current `main`, reconciled with later repository state, independently reviewed and either integrated or retained as explicit WIP.

This record supersedes its earlier continuation state. It does not authorise a TestFlight upload, a product-name adoption, an under-13 test or transfer of evidence between builds.

## Stream results

| Stream | Work item | Disposition | Evidence |
|---|---|---|---|
| ST-01 — TestFlight automation | RH-019A | Retained as published WIP on `codex/rh-019a-testflight-tooling-recovery` at `ee4686d`; no PR by design. | Shell syntax and 27 fail-closed fixture tests passed. Independent standards and task-contract reviews passed. No Apple authentication, build, archive or upload was run. |
| ST-02 — Apple place audit | RH-051 | Integrated through PR 16 at `82e5cb5`. | Six focused Python tests passed; Swift probe compiled; offline dry-run found zero pending requests; regenerated comparison matched byte-for-byte. The corpus contains public synthetic coordinates only. |
| ST-03 — Beta/UAT, headset and test system | RH-052 | Integrated through PR 17 at `67c72d1`. | Receipt hash, local links and document consistency passed. One canonical ride protocol and current exact-build gate replaced duplicate and stale records. |
| ST-04 — Settings build identity | RH-053 | Integrated through PR 18 at `f148845`. | The final unsigned generic-iOS Release build exited 0 with `** BUILD SUCCEEDED **`; all four GitHub checks passed. Review caught and corrected truncated build seconds, so Settings now shows the complete packaged `CFBundleVersion`. |
| ST-05 — Family-product planning | RH-054 | Integrated through PR 19 at `7d50042`. | Local links, diff check, secret scan and both independent reviews passed. No app build or tests were run for this documentation-only stream. |

## RH-045 path dispositions

The final comparison from current `main` to RH-045 contains 48 differing paths. The original preservation comparison contained 55 paths; paths absent from this table now match integrated `main` exactly. Every remaining difference belongs to one of the groups below.

| Group | RH-045 paths | Final disposition |
|---|---|---|
| RH-019A WIP | `.gitignore`; `.ios-testflight.json`; `docs/operations/testflight/APP_STORE_CONNECT_KEY_RUNTIME_HARDENING.md`; `tools/ios-testflight`; `tools/tests/test-ios-testflight.sh`; all six `tools/tests/fixtures/bin/*` executables | Retained together on the published RH-019A WIP branch. They remain intentionally absent from `main` until the API-key runtime-custody gate is resolved. |
| Control plane and ledger | `AGENTS.md`; the RH-045 `ITEM-BACKLOG.md` to `Backlog.md` rename; `README.md`; `docs/README.md`; ledger references in the audio ADR, architecture/audio plans, calibration specification, audio-calibration research and brand-pack README; deletion of `DOCUMENTATION_RECONCILIATION_PLAN.md` | Retain current `ITEM-BACKLOG.md` and current documents. Retire every `Backlog.md` regression and the stale deletion. From RH-045 `AGENTS.md`, retain only the Xcode-interface guidance and iOS-deployment-SOP route; keep the verified `rjbarbour/MotoGuide` origin and the later SOP versions. |
| Release state and historical distribution research | `PROJECT.md`; `APPLE_CLOUD_SIGNING_PERMISSION_RESEARCH_2026-08-06.md`; `IOS_DISTRIBUTION_AUTOMATION_CONTINUATION_2026-08-06.md`; `2026-08-06-ios-risk-calibrated-build-test-distribution.md`; `2026-08-11-app-store-connect-api-tooling-continuation.md` | Retire the stale candidate and credential/tooling history. Current `PROJECT.md`, the canonical iOS deployment SOP and the RH-019A hardening record supersede it without retaining credential identifiers, tester identity or obsolete operator steps. |
| Xcode and build identity | `RideHorizon.xcodeproj/project.pbxproj`; both shared scheme files; `RideHorizon/ContentView.swift` | Retire the old build-number bump and formatting-only scheme churn. Retain only the reviewed Settings card from RH-053; the integrated version deliberately differs because it shows the exact raw build number. |
| Beta/UAT and test documentation | `XCOM2_DOCUMENT_PRINCIPLES.md`; `RIDE_UAT_PROTOCOL.md`; `RIDE_UAT_PROTOCOL_V2.md`; `RIDE_UAT_PROTOCOL_V3.md`; `TESTFLIGHT_FIELD_TEST_EVIDENCE.md`; `TESTFLIGHT_PRIVATE_BETA_PACK.md`; `FIELD_UAT_CONTINUATION_2026-08-06.md`; the six differing `docs/testing/*` records | Retain the RH-052 reconciled versions on `main`. Retire the compatibility pointer, superseded V2, resolved continuation and all stale build-specific variants. |
| Family-product planning | `BACKSEAT_GUIDER_PROJECT_SEQUENCE.md`; `2026-08-10-backseat-name-availability-ip-screen.md`; RH-045 deletion of `FAMILY_JOURNEY_PRODUCT_FRAMEWORK.md` | Retain the integrated framework. Retain the sequence and dated name screen through RH-054 after removing stale Git/ledger state and making the final AMBER name judgement explicit. Reject the framework deletion. |
| Apple place audit | `tools/apple-place-audit/README.md` | Retain the reviewed RH-051 version on `main`; retire the older README wording. The other audit tool, fixture and research paths now match integrated `main`. |

## Deliberate exclusions

- No RH-045 build-number change, scheme reformatting, old release-candidate claim or deprecated ledger filename was transferred.
- No credential value, private ride trace, tester identity or home-location detail was added to `main`.
- No live Apple geocoding, App Store Connect operation, archive or TestFlight upload was used to adjudicate the streams.
- No future family-product feature or name was authorised by preserving its planning evidence.

## Remaining owner gates

1. **RH-019A security gate:** choose either RAM-backed App Store Connect key materialisation or an explicit temporary exception accepting the documented mode-0600 disk-backed temporary-file risk for private-beta uploads.
2. **RH-002 physical evidence gate:** install or update to RideHorizon `0.12.4 (20260806.221234)`, confirm that exact build in Settings while stopped, then decide the release gate from build-specific stationary and road evidence.
3. **Future family-product gates:** decide whether the passenger experiment outranks current RideHorizon work; obtain solicitor-led clearance before adopting **Backseat Guider**; complete the data/compliance gate before involving an under-13 tester.

Only the first gate blocks the retained RH-019A branch from becoming a merge candidate. The other gates do not block repository-hygiene closeout.

## Cleanup gate

This closeout record must be published before the RH-045 source shelf is deleted. After publication:

1. verify merged PRs 16–19 and all relevant branch heads remain independently reachable;
2. remove the clean merged RH-051 to RH-054 worktrees and local branches;
3. delete the RH-045 remote and local branch only after the RH-019A WIP branch and integrated `main` are verified;
4. restore `/Users/rob_dev/DocsLocal/motoguide/repo` as the clean canonical `main` checkout;
5. retain only the clean RH-019A WIP worktree alongside it.

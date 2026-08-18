# App Store Connect key runtime hardening

Date: 2026-08-06

Status: **Temporary private-beta exception accepted. The RAM-volume launcher remains a deferred permanent hardening improvement and is not implemented or verified.**

## Recovery verification — 2026-08-17

RH-019A recovered the script, its project configuration and the complete fixture harness from preservation commit `2a1a31e` onto `codex/rh-019a-testflight-tooling-recovery`, based on current `main`.

- `bash -n tools/ios-testflight tools/tests/test-ios-testflight.sh` passed.
- `./tools/tests/test-ios-testflight.sh` passed all 27 fixtures.
- The empty `appStoreConnectAppID` configuration field is deliberate: the script resolves the app from the configured bundle identifier and uses a non-empty configured ID only as a consistency check.
- No authentication, archive, upload or App Store Connect operation was run.

On 2026-08-17, the owner accepted the existing short-lived, mode-`0600`, disk-backed key copy as a narrow temporary exception for this private-beta workflow. This permits integration of the retained tool; it does not authorise a TestFlight upload or establish the exception as the permanent production design.

## Integration verification — 2026-08-18

- The retained branch was rebased onto current `main`; the obsolete manual-ledger change was excluded.
- Xcode's destination inventory confirmed the configured `iPhone 17` simulator on iOS `26.3.1` is available.
- Shell syntax passed and all 27 fixture cases passed after adding regression coverage that proves `TERM` stops deployment with status `143`, removes the temporary key and prevents upload.
- A focused secret scan reported only the known private-key wording in the tool and the deliberately fake key fixture; it found no credential value in the project configuration or implementation.
- No app build, credential-value read, authentication, archive, signing operation, upload or App Store Connect operation was run.

## Purpose

Replace RideHorizon TestFlight automation's ordinary disk-backed temporary `.p8` copy with the stricter reusable custody chain:

```text
Password Safe recovery copy
→ macOS Keychain runtime source
→ private RAM-backed temporary volume
→ xcodebuild
→ unmount and destroy the RAM volume
```

Apple's command-line authentication requires `xcodebuild -authenticationKeyPath`; Apple does not document a standard-input or direct-Keychain alternative. Xcode must therefore receive a file-like path. A private RAM-backed volume is the closest practical local mechanism to memory-only file materialisation. See [Apple's App Store Connect API authentication explanation](https://developer.apple.com/videos/play/wwdc2021/10204/).

## Current gap

`tools/ios-testflight` currently copies the key into a permission-restricted, short-lived directory under the normal macOS temporary directory. Ownership and mode checks, ordinary cleanup and stale-run recovery reduce exposure, but the temporary copy is disk-backed. It can therefore interact with ordinary filesystem persistence and does not meet the stricter target.

The temporary path remains an explicit private-beta exception only, recorded as Backlog decision `decision-005`. Review the exception periodically and specifically before wider distribution, after runner or custody changes, after any cleanup failure or suspected exposure, and at release-tooling milestone health gates. Rotate the API key after the RAM-volume procedure is operational, or sooner if exposure is suspected.

## Governing SOP

Before any authenticated check, archive or upload, fetch and follow all of these sources:

- [SOP: iOS Build and TestFlight Deployment v1.0](https://app.notion.com/p/3b4a4c502b1781e18977d4e2d9b75c74);
- [SOP: Xcode App Store Connect API Key Runtime Handling v1.0](https://app.notion.com/p/3b4a4c502b1781d5addefb4f28e5fa8e);
- [SOP: Secret Management in Agentic AI Development v3.0](https://www.notion.so/320a4c502b1781d9ab34c4abf6d44152); and
- [SOP: macOS Keychain Credential Discovery and Access v1.0](https://app.notion.com/p/3aea4c502b17811bb795c545f601bd6f).

The runtime-key SOP is the generic design and operating authority for temporary key materialisation. This project note contains only the RideHorizon adoption gap and acceptance evidence.

`./tools/ios-testflight doctor` is a local operator preflight, not an LLM-safe diagnostic collector. Do not paste its raw output into an AI session. If a diagnostic evidence script is needed, build and run it under [SOP: Diagnostic Script Standards for LLM-Assisted Debugging v1.0](https://app.notion.com/p/324a4c502b1781298a2cc9cd702fb31b), including collection-time redaction and the required output markers.

## Temporary-exception controls

- Restrict use to the retained private-beta workflow.
- Keep the temporary key copy short-lived, owner-only and mode `0600`.
- Preserve fail-closed cleanup and stale-run recovery.
- Treat each authenticated check, archive, signing operation and upload as a separate authorised operation under the governing SOPs.
- Record only non-secret evidence and never expose credential values in commands, logs, receipts or agent-visible output.
- Revisit `decision-005` at every listed review trigger; do not silently broaden the exception.

## Permanent hardening acceptance evidence

- A reviewed launcher reads one exact Keychain item without returning the value through agent-visible output.
- It creates a new private RAM-backed volume for each execution and writes no key copy to the repository, `$TMPDIR`, `/tmp`, logs, arguments, environment variables, receipts, Spotlight or backup locations.
- The temporary `.p8` is a regular file owned by the current user with mode `0600`.
- `xcodebuild` receives only the RAM-volume path, key ID and issuer ID.
- Cleanup unmounts and destroys the volume after success, ordinary failure and each catchable signal.
- Strictly validated stale-resource recovery handles an uncatchable crash without targeting unrelated devices or mount points.
- Fixture tests prove wrong ownership, mode, symlink, empty value, authentication failure, cleanup failure and stale-resource cases fail closed.
- A controlled non-secret App Store Connect capability check and one Internal Only deployment pass.
- The migration key is rotated after the permanent procedure is proven.

## Scope

Implement this in reusable iOS distribution tooling. Keep only non-secret project configuration and the SOP link in RideHorizon. Do not make it a RideHorizon app feature or duplicate the general secret-handling policy here.

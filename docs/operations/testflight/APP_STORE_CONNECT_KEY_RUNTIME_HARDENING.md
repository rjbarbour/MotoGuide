# App Store Connect key runtime hardening

Date: 2026-08-06

Status: **Deferred tooling improvement. The target procedure is documented, but the RAM-volume launcher is not implemented or verified.**

## Recovery verification — 2026-08-17

RH-019A recovered the script, its project configuration and the complete fixture harness from preservation commit `2a1a31e` onto `codex/rh-019a-testflight-tooling-recovery`, based on current `main`.

- `bash -n tools/ios-testflight tools/tests/test-ios-testflight.sh` passed.
- `./tools/tests/test-ios-testflight.sh` passed all 27 fixtures.
- The empty `appStoreConnectAppID` configuration field is deliberate: the script resolves the app from the configured bundle identifier and uses a non-empty configured ID only as a consistency check.
- No authentication, archive, upload or App Store Connect operation was run.

The branch remains work in progress because the disk-backed temporary-key path below has not been replaced or explicitly accepted for continued release use.

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

The temporary path remains an explicit migration exception only. Rotate the API key after the RAM-volume procedure is operational, or sooner if exposure is suspected.

## Governing SOP

[SOP: Xcode App Store Connect API Key Runtime Handling v1.0](https://app.notion.com/p/3b4a4c502b1781d5addefb4f28e5fa8e) is the generic design and operating authority. It is governed by the general Secret Management, macOS Keychain and CLOAKD standards. This project note contains only the RideHorizon adoption gap and acceptance evidence.

## RideHorizon acceptance evidence

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

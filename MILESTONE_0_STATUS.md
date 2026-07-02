# Milestone 0 Status

Date: 2026-07-02

## Result

Milestone 0 is complete for local checkout, project inspection, and simulator unit-test verification.

Physical iPhone deployment is now recorded as completed over the newer CoreDevice / OTA path.

This thread installed and launched MotoGuide on Robert's iPhone over OTA on 2026-07-02. The companion thread also observed the phone via `xcrun devicectl list devices` as `Roberts-iPhone-17.coredevice.local`. `xcodebuild -showdestinations` may still fail to list the phone even when CoreDevice can see it.

## Local Checkout

Path:

```bash
/Users/rob_dev/DocsLocal/motoguide/repo
```

Expected result: this folder contains `.git`, `MotoGuide.xcodeproj`, `MotoGuide/`, `MotoGuideTests/`, `MotoGuideUITests/`, `AGENTS.md`, and `MILESTONES.md`.

Actual result: present.

## Repository

Command:

```bash
git remote -v
```

Expected result:

```text
origin	https://github.com/rjbarbour/MotoGuide.git (fetch)
origin	https://github.com/rjbarbour/MotoGuide.git (push)
```

Actual result: matched.

## Project Inspection

Command:

```bash
xcodebuild -list -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj
```

Expected result: prints the project targets, build configurations, and schemes.

Actual result:

```text
Targets:
    MotoGuide
    MotoGuideTests
    MotoGuideUITests

Build Configurations:
    Debug
    Release

Schemes:
    MotoGuide
```

## Historical Simulator Test Attempt

Command:

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'platform=iOS Simulator,name=iPhone 15' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData
```

Expected result: the MotoGuide unit and UI test targets build and run in an iOS Simulator.

Actual result: failed with exit code `70`.

Reason:

```text
Unable to find a device matching the provided destination specifier:
{ platform:iOS Simulator, OS:latest, name:iPhone 15 }
```

Additional destination check:

```bash
xcodebuild -showdestinations -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide
```

Actual result:

```text
Ineligible destinations for the "MotoGuide" scheme:
{ platform:iOS, name:Any iOS Device, error:iOS 26.2 is not installed. Please download and install the platform from Xcode > Settings > Components. }
```

XcodeBuildMCP simulator list result: no enabled simulators.

## Compile-Only Attempt

Command:

```bash
xcodebuild build -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'generic/platform=iOS Simulator' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData
```

Expected result: compile the app for a generic iOS Simulator destination.

Actual result: failed with exit code `65`.

Reason:

```text
error: No available simulator runtimes for platform iphonesimulator.
```

The build reached Swift compilation setup but failed during asset catalog compilation because no iOS simulator runtime was installed.

## Updated Simulator Test Result

Command:

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData -only-testing:MotoGuideTests
```

Expected result: the MotoGuide unit test target builds and runs in the iOS Simulator.

Actual result: **BUILD SUCCEEDED** and **TEST SUCCEEDED** on iPhone 17 simulator running iOS 26.3.1. This result was recorded in `MILESTONE_1_STATUS.md` on 2026-07-01.

## OTA Device Deploy Result

Device:

```text
Robert's iPhone 17
Hostname: Roberts-iPhone-17.coredevice.local
Identifier: B0D90B81-8AC6-57B6-AC4E-717EA505D3DD
```

Expected result: MotoGuide is installed on Robert's iPhone without a USB cable after the phone remains visible to CoreDevice.

Actual result: OTA install and launch completed successfully on 2026-07-02.

Commands:

```bash
xcrun devicectl list devices
```

Expected result: prints `Robert's iPhone 17` as `available (paired)`.

Actual result: `Robert's iPhone 17` was available over `Roberts-iPhone-17.coredevice.local`.

```bash
xcodebuild build -quiet -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'generic/platform=iOS' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData -allowProvisioningUpdates
```

Expected result: builds `DerivedData/Build/Products/Debug-iphoneos/MotoGuide.app`.

Actual result: build succeeded.

```bash
xcrun devicectl device install app --device B0D90B81-8AC6-57B6-AC4E-717EA505D3DD /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData/Build/Products/Debug-iphoneos/MotoGuide.app
```

Expected result: installs MotoGuide on Robert's iPhone.

Actual result: installed bundle `ai.dml.MotoGuide`.

```bash
xcrun devicectl device process launch --device B0D90B81-8AC6-57B6-AC4E-717EA505D3DD ai.dml.MotoGuide
```

Expected result: launches MotoGuide on Robert's iPhone.

Actual result: launched application with bundle identifier `ai.dml.MotoGuide`.

## Human-Operable Next Steps

Primary physical test device:

```text
iPhone 17 Pro Max running iOS 26.5.1
```

This means Xcode/CoreDevice must support development for iOS 26.5.1 before physical-device testing can work reliably. If Xcode 26.3 cannot install or support the matching device support files, update Xcode first.

Before repeating OTA deployment, confirm the phone is visible to CoreDevice:

```bash
xcrun devicectl list devices
```

Expected result: prints `Robert's iPhone` or `Roberts-iPhone-17.coredevice.local` as connected.

If using the older Xcode destination path, this command may or may not list the phone:

```bash
xcodebuild -showdestinations -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide 2>&1 | rg "Robert's iPhone"
```

Expected result: prints a destination line for `Robert's iPhone` when Xcode exposes the phone as a run destination.

1. Build, install, and launch on Robert's iPhone:

```bash
xcodebuild build -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'platform=iOS,id=00008150-000C70883E87401C' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData -allowProvisioningUpdates
```

Expected result: MotoGuide builds for Robert's iPhone.

2. Install the app:

```bash
xcrun devicectl device install app --device 00008150-000C70883E87401C /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData/Build/Products/Debug-iphoneos/MotoGuide.app
```

Expected result: the latest MotoGuide build installs on Robert's iPhone.

3. Launch the app:

```bash
xcrun devicectl device process launch --device 00008150-000C70883E87401C ai.dml.MotoGuide
```

Expected result: MotoGuide opens on Robert's iPhone.

Actual result on 2026-07-02: MotoGuide launched over OTA using CoreDevice.

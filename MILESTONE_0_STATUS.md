# Milestone 0 Status

Date: 2026-07-01

## Result

Milestone 0 is complete except for a successful simulator test run. The code is cloned locally, the project is readable by Xcode tooling, the scheme is identified, and the blocker is documented.

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

## Simulator Test Attempt

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

The build reached Swift compilation setup but failed during asset catalog compilation because no iOS simulator runtime is installed.

## Human-Operable Next Steps

Primary physical test device:

```text
iPhone 17 Pro Max running iOS 26.5.1
```

This means Xcode must support development for iOS 26.5.1 before physical-device testing can work reliably. If Xcode 26.3 cannot install or support the matching device support files, update Xcode first.

1. Install an iOS simulator runtime in Xcode, or update Xcode if needed for iOS 26.5.1 device support:

```bash
open -a Xcode
```

Expected result: Xcode opens.

Then use `Xcode > Settings > Components` and install the iOS runtime requested by this Xcode install.

2. After the runtime is installed, rerun:

```bash
xcodebuild test -project /Users/rob_dev/DocsLocal/motoguide/repo/MotoGuide.xcodeproj -scheme MotoGuide -destination 'platform=iOS Simulator,name=iPhone 15' -derivedDataPath /Users/rob_dev/DocsLocal/motoguide/repo/DerivedData
```

Expected result: tests build and run on the selected simulator.

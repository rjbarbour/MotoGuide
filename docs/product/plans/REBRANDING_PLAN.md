# RideHorizon Identity Migration Plan

Date: 2026-07-17

## Decision

Rename the current prototype to **RideHorizon** before the first App Store Connect build upload. This is a clean break: active source, tests, configuration, documentation, and infrastructure declarations must not retain the previous product identity.

The initial public service host is `ridehorizon.digitalmercenaries.ai`. The intended future public host is `ridehorizon.app` if it becomes available after private beta.

## Identity Map

| Role | Value |
|---|---|
| Product name | `RideHorizon` |
| Lowercase identifier | `ridehorizon` |
| iOS bundle identifier | `ai.digitalmercenaries.ridehorizon` |
| Swift module and Xcode target | `RideHorizon` |
| Java package and Gradle group | `ai.digitalmercenaries.ridehorizon.factproxy` and `ai.digitalmercenaries.ridehorizon` |
| Proxy service name | `ridehorizon-fact-proxy` |
| Initial public proxy host | `ridehorizon.digitalmercenaries.ai` |
| Keychain services | `RideHorizonProxy`, `RideHorizonDeviceId` |
| HTTP identity headers | `X-RideHorizon-User-Id`, `X-RideHorizon-Device-Id` |
| Server configuration prefix | `ridehorizon` |
| Non-secret server setting prefix | `RIDEHORIZON_` |

## Scope

- Rename Xcode project, app target, test targets, folders, files, Swift module imports, and bundle identifiers.
- Rename Java packages, source/test paths, Gradle group, Spring configuration prefix, HTTP headers, OpenAPI, scripts, deployment declarations, and current documentation.
- Introduce one small product-identity module so rider-visible app name is not duplicated in Swift UI copy.
- Delete the existing local debug install before testing the renamed app. No preference, cache, or Keychain migration is required because there is no external beta cohort.

## Explicit Deployment Constraint

AXON SOP: Secret Management in Agentic AI Development v3.0 requires deployed application secrets to be stored in AWS Secrets Manager and retrieved at runtime. The existing Fly deployment's environment-secret model does not meet that rule.

This rebrand may rename non-secret configuration identifiers but must not deploy, copy, print, rotate, or otherwise handle secret values. Deploying the renamed proxy is blocked until the proxy has an approved runtime AWS Secrets Manager retrieval design and an authorised workload identity.

## Acceptance Criteria

- Apple App ID and Xcode target use `ai.digitalmercenaries.ridehorizon` before the first upload.
- Active source, tests, configuration, scripts, and current documentation contain no previous product identity references.
- Dated historical reports are either clearly labelled historical or archived outside active documentation.
- The Italy onboarding splash uses a full-size touring motorcycle being ridden on the Stelvio Pass, includes an example location description, and displays the Creative Commons attribution in the app.
- The temporary onboarding road-mark icon is approximately three times its original size and remains legible within the phone-width layout.
- Xcode builds the renamed app and its tests import the renamed module.
- Fact-proxy tests compile under the renamed Java package.
- A final scoped `rg` audit reports no old identity in active files.

## Verification

1. Build the iOS app for the physical iPhone.
2. Run the iOS unit tests on the simulator.
3. Run the fact-proxy test suite.
4. Run the zero-match identity audit.
5. Do not deploy the proxy until the deployment constraint is resolved.

## 2026-07-17 Validation Result

- The renamed Xcode project parses and lists `RideHorizon`, `RideHorizonTests`, and `RideHorizonUITests`.
- Xcode signing is blocked until the developer signs the same Apple account into Xcode and creates the `ai.digitalmercenaries.ridehorizon` App ID/provisioning profile.
- An unsigned iOS build reached asset compilation but cannot complete in this environment because CoreSimulator has no available runtime. This is an environment limitation, not a reported Swift or project-reference error.
- `./gradlew test` passes for the renamed fact proxy.
- Info.plist and entitlements validate with `plutil`; the OpenAPI specification parses; the scoped legacy-identity content and filename audits pass.

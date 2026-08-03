# Tactical iOS Proxy Access — 2026-07-27

Status: Superseded on 2026-07-31. The direct-token screen and manual secret path were removed. Current Debug and Release builds provision restricted sessions automatically through `/v1/session/fallback`; testers never enter or receive a proxy token.

## Request

Allow the current OTA Debug build to bypass the unfinished App Attest work and use the proxy as deployed for same-day functional testing.

## Deployed state

- `https://motoguide-fact-proxy.fly.dev/health` returns HTTP `200`.
- `https://ridehorizon.digitalmercenaries.ai` does not currently resolve.
- The iOS app already targets the healthy legacy host through `FactProxyContract.useLegacyProductionProxy`.
- A valid `RideHorizonProxy` item is available in macOS Keychain.

## Historical tactical implementation

- In Debug builds only, show a development proxy-access screen when the iOS Keychain has no proxy token.
- Accept a proxy token directly and store it in the iOS Keychain service `RideHorizonProxy`.
- Keep the in-progress automatic session coordinator unchanged for Release and TestFlight builds.
- Never embed, print, log, document, or pass the token through a command-line argument.
- Copy the token from macOS Keychain directly to the clipboard with command output suppressed, then paste it into the phone's secure field.

## Acceptance criteria

1. The Debug app can store a directly entered proxy token and proceed to the normal app UI.
2. Release builds cannot use the direct-token path.
3. The in-progress automatic session path remains unchanged outside the Debug-only gate.
4. Unit tests cover direct-token storage success and failure without real credential material.
5. The physical-device build succeeds, installs OTA, and launches.
6. No secret value appears in source, build output, logs, documentation, or chat.

## Removal completed — 2026-07-31

The Debug-only direct-token path was removed after automatic restricted session provisioning was deployed. Full App Attest verification remains deferred; the fallback session is deliberately quota-limited and does not claim to be attested.

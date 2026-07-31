# RideHorizon Project State

Last verified: 2026-07-31

## Current commitment

Prepare a private external TestFlight beta for 3–5 named iPhone testers. This is a **Build** commitment: preserve the narrow MVP while increasing release, privacy, safety and reliability evidence.

## Last verified result

RideHorizon `0.12.3 (20260731.1942)` is the current hardening candidate. The public privacy policy and Cloudflare-to-Fly health path are live. Automatic restricted sessions, OpenAI facts and ElevenLabs speech passed a fresh production check. The full 100-test iOS unit suite, fact-proxy Gradle suite, Cloudflare edge suite and three-test clean-install simulator UI suite pass; the simulator app was uninstalled and permissions reset before that recorded UI run. Simulator review found and fixed horizontally clipped onboarding copy and non-scrollable compact-landscape content. The replacement Release archive passed Xcode's local store, packaging, privacy, icon, symbol and signature checks. This exact build still requires a physical-iPhone install and App Store Connect upload; both are waiting on local device/account availability.

## Delivery Risk Cube

- **Functional breadth:** Sufficient for the private beta: onboarding, location awareness, Test Mode, names, facts, Apple Voice, Premium Voice and Quiet Mode.
- **Implementation fidelity:** Live services, clean-install compact-iPhone portrait and landscape evidence, and a validated layout-corrected Release archive exist; physical-device installation, App Store Connect processing and TestFlight installation remain unproved.
- **Production-quality depth:** Privacy policy, consent, no pre-consent proxy access, explicit in-app rider-safety wording, minimal background modes, iPhone-only packaging, provider fallback and green automated checks are in place. Real-world background location, battery and Bluetooth evidence remains the largest gap.

## Current gate

Complete RH-001 in `Backlog.md`. When available, reconnect and unlock the target iPhone. Refresh the Apple ID session in Xcode, install exact build `20260731.1942`, then retry the App Store Connect upload. Do not start RH-002 until Apple finishes processing this build.

## Residual risks

- App Attest enforcement remains deferred behind restricted automatic sessions.
- App Store Connect privacy answers and legal/account declarations require Rob's confirmation.
- Fly is configured with `min_machines_running = 0`. One 2026-07-31 cold-start health request exceeded 20 seconds before the machine became healthy; choose whether to keep one machine warm during TestFlight or accept occasional first-request Apple Voice fallback.
- Background location, battery and Bluetooth behaviour require evidence from the exact TestFlight build and real rides.

## Next outcomes

1. RH-001: hardened, reviewed and uploaded release candidate.
2. RH-002: clean internal TestFlight smoke and external review submission.
3. After the milestone gate, decide whether to continue to App Attest hardening or pause for private-beta evidence.

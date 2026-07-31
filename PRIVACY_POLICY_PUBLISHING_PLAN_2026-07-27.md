# RideHorizon Privacy Policy Publishing Plan

Date: 2026-07-27

Status: Automatic work completed as far as current access safely allows

## Outcome on 2026-07-27

- Replaced the failed legacy host with a Cloudflare Pages deployment at `https://ridehorizon-edge.pages.dev/app-privacy-policy`. The page, security headers, Fly proxy health route, automatic session flow, and ElevenLabs speech route were verified on 2026-07-31. The final URL remains `https://ridehorizon.digitalmercenaries.ai/app-privacy-policy`; Cloudflare custom-domain association and the Namecheap `ridehorizon` CNAME are still required before TestFlight submission.
- Kept the product proposition separate: RideHorizon provides short audio place context for motorcyclists alongside their normal navigation.
- Added the public policy link to the in-app privacy notice and completed a generic iOS device build successfully.
- Confirmed the physical iPhone was not connected, so installation and launch remain manual.
- Did not deploy the proxy: the production Fly machine is stopped and the concurrent backend work has failing tests. Deploying that state would be unsafe and outside this scoped change.

## User Request

Separate the remaining privacy and App Store preparation work into tasks Codex can complete automatically and tasks that require the account holder, legal decision-maker, or physical test device. Complete the automatic work as far as current access allows, including drafting and publishing a privacy policy if possible.

## Automatic Work

1. Verify the implemented app and proxy data flows against the 2026-07-18 privacy audit.
2. Research current policy requirements and provider-retention statements from primary sources.
3. Draft a plain-language RideHorizon privacy policy that matches the current app and does not promise unimplemented remote deletion.
4. Add the policy to the existing RideHorizon website and build it successfully.
5. Publish a production version as far as the available hosting access safely permits.
6. Add the final public policy URL to the iOS privacy notice after the public URL is confirmed.
7. Check the proxy deployment state and deploy only from a clean, verified source state that excludes unrelated unfinished work.
8. Check whether the physical iPhone is connected; build, install, and launch if available.

## Manual Work

1. Approve the policy as the company/controller; obtain legal review if desired.
2. Confirm the monitored privacy-contact email and company/controller details used in the policy.
3. Make or approve public website access when hosting requires an explicit public-access decision.
4. Verify ElevenLabs Zero Retention Mode is enabled for the production account.
5. Verify the OpenAI organisation's data-retention controls and contract settings.
6. Enter the public privacy-policy URL and final App Privacy answers in App Store Connect.
7. Define and operate the identity-check process for remote deletion requests before promising remote deletion.
8. Perform the real-ride, Bluetooth-headset, locked-screen, background-location, and background-audio checks on the physical iPhone.

## Acceptance Criteria

- The policy accurately names RideHorizon, the controller, the data categories, purposes, providers, retention, user choices, local deletion limits, security, children, international processing, changes, and contact route.
- The policy is presented as conventional legal information. Privacy is not positioned as RideHorizon’s product purpose or unique selling point.
- Product-facing copy leads with RideHorizon’s actual purpose: short audio place context for motorcyclists alongside normal navigation.
- The policy distinguishes precise GPS processed on device from place names sent to optional AI providers.
- The policy states that OpenAI and ElevenLabs processing occurs only after explicit permission and explains the Apple Voice/non-AI fallback.
- The website build succeeds and the exact source state is saved before deployment.
- No secret value is written to source, documentation, logs, shell configuration, or hosting metadata.
- All steps that require the user's judgement, provider-account access, App Store Connect access, or physical riding are reported as manual rather than guessed complete.

## Binding Procedure

The AXON `SOP: Secret Management in Agentic AI Development v3.0` was fetched on 2026-07-27. Hosting credentials must be short-lived, used only for the current operation, and never persisted in source, documentation, logs, or chat.

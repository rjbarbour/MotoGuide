# RideHorizon fact proxy Terraform

This folder contains the Fly.io infrastructure as code for the fact proxy service.

Current scope:

- Provision the `ridehorizon-fact-proxy` Fly app shell.
- Keep the app name/org as code.
- Keep secrets out of Git.

Runtime secrets are managed directly in Fly Secrets. GitHub Actions stores only the
`FLY_API_TOKEN` needed to deploy the existing app and does not copy provider keys or
RideHorizon credentials between secret stores.

## Prerequisites

- Terraform >= 1.5.0
- `FLY_API_TOKEN` set in your shell or CI secret
- Optional: the GitHub Actions `FLY_API_TOKEN` repository secret for automated deployment.

## Files

- `main.tf` — `fly_app` resource and provider configuration
- `variables.tf` — app name and org variables
- `outputs.tf` — useful outputs for scripts and checks

## First-time bootstrap

1. Set token:
   - `export FLY_API_TOKEN=fo1_...`
2. Initial import (if the app already exists):
   - `cd fact-proxy/terraform`
   - `terraform init -input=false`
   - `terraform import fly_app.fact_proxy ridehorizon-fact-proxy`
3. Apply:
   - `terraform apply`
4. Run a manual `flyctl deploy`; subsequent tested changes can use the GitHub workflow.

## CI deployment flow

The `Tests` workflow runs iOS and fact-proxy tests for pull requests and pushes to
`main`. The workflow `.github/workflows/fact-proxy-deploy.yml` then performs:

1. Verify that the completed `Tests` run was a successful push to this repository's `main` branch.
2. Deploy the exact tested commit to the current `motoguide-fact-proxy` Fly origin.
3. Smoke-check the stable `ridehorizon.digitalmercenaries.ai` edge end to end.

The legacy Fly app name is an infrastructure compatibility detail. Released iOS
builds use only the RideHorizon edge. Keep deployment on the current origin until
the replacement Fly app exists and the Cloudflare origin has been cut over; then
set the `FLY_APP_NAME` repository variable to the replacement app.

Terraform remains the manual app-shell bootstrap and recovery path. It is not run
from an ephemeral CI runner because the project does not yet have a shared remote
Terraform state backend.

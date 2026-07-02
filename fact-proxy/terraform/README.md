# MotoGuide fact proxy Terraform

This folder contains the Fly.io infrastructure as code for the fact proxy service.

Current scope:

- Provision the `motoguide-fact-proxy` Fly app shell.
- Keep the app name/org as code.
- Keep secrets out of Git by passing them from CI/local environment variables.

Secrets (for CI) are still applied through GitHub Actions and `flyctl secrets set`.

## Prerequisites

- Terraform >= 1.5.0
- `FLY_API_TOKEN` set in your shell or CI secret
- Optional: GitHub Actions workflow variables/secrets as documented below.

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
   - `terraform import fly_app.fact_proxy motoguide-fact-proxy`
3. Apply:
   - `terraform apply`
4. Run deploy via existing GitHub workflow or manual `flyctl deploy`.

## CI deployment flow

The workflow `.github/workflows/fact-proxy-deploy.yml` performs:

1. Terraform init/validate and apply of app definition
2. `flyctl secrets set` for runtime variables:
   - `OPENAI_API_KEY`
   - `MOTOGUIDE_PROXY_TOKEN`
   - `OPENAI_MODEL`
   - optional host allowlist/auth token
3. `flyctl deploy --config fly.toml`

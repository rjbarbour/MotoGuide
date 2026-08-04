# RideHorizon public-site infrastructure and CI

Date: 2026-08-04

## Bottom line

Use three bounded workstreams. The recommended delivery order is CI reporting, report remediation, then the deferred API-host split:

1. Add a small production CI loop: retain the current Worker tests during compatibility, then deploy, run Lighthouse CI and Lychee against the three explicit live pages, and retain their raw reports.
2. Add agent-assisted remediation as a separate increment that consumes those reports and prepares a reviewed fix-forward change. Do not let an agent patch production directly.
3. Later, move the iOS API to `api.ridehorizon.digitalmercenaries.ai`, while preserving the current shared-host Worker routes for every distributed build that still uses them.

Once the old iOS hostname is no longer required, make the website genuinely static and remove `_worker.js` and its Node tests. Removing Wrangler from the repository is possible, but the existing Pages project was created by Direct Upload. Cloudflare states that a Direct Upload project cannot later switch to Git integration, so this requires a new Git-integrated Pages project and a controlled custom-domain cutover.

## Current repository facts

- `privacy-site/site/_worker.js` maps `/`, `/support` and `/app-privacy-policy` to static files and proxies every other path to `motoguide-fact-proxy.fly.dev`.
- `privacy-site/test/router.test.mjs` and `node --test` test that bespoke routing and proxy behaviour.
- Wrangler is a deployment/local-preview tool here, not a site generator. The pages are handwritten HTML.
- `privacy-site/README.md` shows that `ridehorizon-edge` was created and deployed with `wrangler pages ...`; this is Cloudflare's Direct Upload model.
- `RideHorizon/ProxyFactGenerator.swift`, the proxy contract, smoke scripts and deployment workflow currently use `https://ridehorizon.digitalmercenaries.ai` as the API base URL.

## Deferred track: separate the API hostname

### Recommended sequence

1. **Inventory compatibility before changing DNS.** Record which uploaded/distributed iOS builds use the shared hostname. The repository proves the current code does, but it does not prove which builds remain active in TestFlight.
2. **Attach the new hostname to the existing Fly app.** Fly supports custom subdomains and states that CNAME records work well for them. Add `api.ridehorizon.digitalmercenaries.ai` to `motoguide-fact-proxy`, then create exactly the DNS and ownership records Fly reports. Fly requires domain verification before issuing or renewing the certificate. [Fly custom domains](https://fly.io/docs/networking/custom-domain/)
3. **Verify the new endpoint before changing the app.** Check certificate status, public `/health`, authenticated session creation, `/v1/fact` and `/v1/speech`. This is an additive change: the existing website/Worker path remains intact.
4. **Change and release a replacement iOS build.** Update the production base URL, Swift tests, OpenAPI server URL, live smoke script, fact-quality script and deployment smoke check to the API subdomain. Keep privacy, support and marketing URLs on the website hostname.
5. **Retain compatibility.** Continue routing the old `/health`, `/v1/session/*`, `/v1/fact` and `/v1/speech` paths through the Worker while any usable distributed build may call them.
6. **Prove retirement, then remove compatibility.** Require evidence that all active testers are on a build using the API subdomain, or that earlier builds can no longer be used. If possible, also inspect old-host traffic before removal. A calendar delay alone is weaker evidence.
7. **Restructure the static site.** Make the landing page `site/index.html`; place the privacy and support pages at `site/app-privacy-policy/index.html` and `site/support/index.html`; add `_headers`, `robots.txt`, `llms.txt` and any chosen `404.html`/sitemap. Pages serves matching HTML at extensionless paths and supports headers through a static `_headers` file. [Serving Pages](https://developers.cloudflare.com/pages/configuration/serving-pages/), [Pages headers](https://developers.cloudflare.com/pages/configuration/headers/)
8. **Delete the now-unused runtime code.** Remove `_worker.js`, its routing tests and the Node package files only after production has passed the static-site checks and old iOS compatibility is no longer needed.

### Removing Wrangler

The current Direct Upload project cannot be converted to Git integration. Cloudflare requires a new Pages project for that change. [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/)

Recommended cutover:

1. Create a second Git-integrated Pages project connected to this repository, with `privacy-site` as its root, no framework/build step, and `site` as its output directory. Cloudflare supports static HTML without a framework and monorepo root directories. [Static HTML](https://developers.cloudflare.com/pages/framework-guides/deploy-anything/), [build configuration](https://developers.cloudflare.com/pages/configuration/build-configuration/)
2. Restrict builds to public-site paths and validate the new immutable `pages.dev` deployment URL.
3. Keep the old project intact as the rollback target while detaching the custom domain from it and attaching the domain to the new project. Cloudflare requires the domain to be associated with the destination project; a CNAME alone is insufficient. [Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/)
4. Re-run the production checks on the custom domain, then retain the old project for a defined observation period before deletion.

This domain reassignment is not documented as atomic and may involve certificate/DNS activation time. Schedule it as a controlled cutover. Cloudflare explicitly calls unique preview deployments atomic, but does not make the same explicit claim for production custom-domain reassignment. [Preview deployments](https://developers.cloudflare.com/pages/configuration/preview-deployments/)

## First delivery increment: 80/20 website CI

### While the compatibility Worker exists

Use only:

- Current `node --test` Worker tests before deployment.
- Lighthouse CI against `/`, `/support` and `/app-privacy-policy` after deployment.
- Lychee against those same three explicit live URLs after deployment.

Lychee is not a recursive website crawler. Each page must be supplied explicitly. It supports JSON and JUnit reports and returns stable failure exit codes. [Lychee](https://github.com/lycheeverse/lychee), [Lychee Action](https://github.com/lycheeverse/lychee-action)

Lighthouse CI runs, asserts and saves Lighthouse results. Use error assertions for stable accessibility, SEO and best-practice audits; keep performance as a warning initially because it varies. Save raw JSON and HTML to filesystem output rather than public temporary storage. [Lighthouse CI configuration](https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/configuration.md), [Lighthouse variability](https://github.com/GoogleChrome/lighthouse/blob/main/docs/variability.md)

Important version constraint: current `@lhci/cli` 0.15.1 pins Lighthouse 12.6.1. The `llms.txt` audit arrived in Lighthouse 13.2 and the agentic category became part of the default configuration in 13.3. Therefore current Lighthouse CI does **not** validate `llms.txt`. Lychee can prove that the explicit URL resolves, but not validate its format. Recheck the dependency when implementing; either accept that temporary gap or run standalone Lighthouse 13.3 until Lighthouse CI catches up. [Current LHCI dependency](https://raw.githubusercontent.com/GoogleChrome/lighthouse-ci/main/packages/cli/package.json), [Lighthouse 13.3](https://github.com/GoogleChrome/lighthouse/releases/tag/v13.3.0)

### Workflow shape

1. Run the existing repository tests on the candidate commit.
2. Serialise production publication with one concurrency group.
3. Deploy the tested commit to Cloudflare Pages.
4. Run Lighthouse CI and Lychee against the live custom domain.
5. Upload reports even when checks fail: Lighthouse JSON/HTML/manifest and Lychee JSON or JUnit, plus commit SHA, deployment URL and tool versions. GitHub artifacts persist outputs after a job and can be downloaded by later jobs or tools. [GitHub workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
6. Mark the workflow/deployment failed if a hard assertion fails and enable failed-workflow notifications. [GitHub workflow notifications](https://docs.github.com/en/actions/concepts/workflows-and-actions/notifications-for-workflow-runs)

GitHub Actions can run post-deployment jobs. A failed check marks the workflow/deployment unsuccessful but does not undo Cloudflare state. GitHub environments create deployment records, and concurrency prevents overlapping production runs. [GitHub deployments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments)

### Rollback policy

- **Default:** alert and fix forward through a pull request.
- **Manual rollback:** use for deterministic catastrophic failures such as required pages returning 404/5xx or the wrong deployment being published.
- **Do not auto-rollback:** Lighthouse score changes, external-link failures, timeouts or other potentially transient signals.

Cloudflare retains successful production deployments and can instantly repoint production to one of them; preview deployments are not rollback targets. Automatic rollback is possible through Cloudflare's API, but it would need explicit workflow logic and is not proportionate yet. [Pages rollbacks](https://developers.cloudflare.com/pages/configuration/rollbacks/), [rollback API](https://developers.cloudflare.com/api/typescript/resources/pages/subresources/projects/subresources/deployments/methods/rollback/)

After the Worker is retired, remove its Node tests. The remaining CI tools may themselves run on Node or as GitHub Actions, but the website will have no Node application, build step or project dependency.

## Second delivery increment: structured-report remediation

Implement this separately after the checks produce useful reports:

1. On a failed run, collect the exact commit, production deployment URL, raw Lighthouse results and Lychee report.
2. Give those artifacts and the checked-out source to a coding agent.
3. Require the agent to classify transient/infrastructure failures separately from source defects, make the smallest source change, and open a pull request rather than write to `main` or production.
4. Run the same deterministic checks on the corrective commit; merge and redeploy only after they pass.
5. Preserve both the failing and passing reports as evidence.

GitHub exposes artifacts through its Actions API, so this can later be automated without inventing a new report format. [GitHub Actions artifacts API](https://docs.github.com/en/rest/actions/artifacts)

## Open decisions and uncertainties

- Which iOS builds remain usable and therefore define the old-host compatibility window.
- Whether to accept a brief `llms.txt` validation gap or add standalone Lighthouse 13.3 temporarily.
- Whether the new Git-integrated Pages project should replace the current project immediately after API retirement or during a separate maintenance window.
- Exact CI action versions and assertion thresholds should be pinned from a baseline run during implementation, not guessed in this research note.

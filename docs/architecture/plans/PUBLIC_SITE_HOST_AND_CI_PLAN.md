# RideHorizon Public Site Host and CI Plan

Date: 2026-08-04

Status: Shaping. This plan records direction and sequence; it does not authorise DNS, hosting, iOS endpoint, workflow or production changes.

## Outcome

RideHorizon eventually has two explicit public boundaries:

- `https://ridehorizon.digitalmercenaries.ai` is a static product, support and privacy website.
- `https://api.ridehorizon.digitalmercenaries.ai` is the stable iOS API hostname in front of the Fly proxy.

Until distributed iOS builds no longer depend on the shared hostname, the existing Cloudflare Worker remains as a compatibility edge. Independently, the public site gains a proportionate CI pipeline whose structured reports feed a separate remediation increment.

## Current State

- The iOS `FactProxyContract.productionBaseURL` is `https://ridehorizon.digitalmercenaries.ai`.
- Cloudflare Pages serves `/`, `/support` and `/app-privacy-policy` as static assets.
- The Pages `_worker.js` forwards every other path to `https://motoguide-fact-proxy.fly.dev`.
- The repository therefore contains a small Node-based Wrangler project and Worker unit tests.
- `privacy-site` has no GitHub Actions deployment or website-quality workflow.
- `/robots.txt` and `/llms.txt` currently fall through to Fly and return an authenticated API response rather than static website files.

## Decisions and Boundaries

1. Keep the compatibility Worker for now. Do not break an uploaded or distributed iOS build merely to simplify the website.
2. Use `api.ridehorizon.digitalmercenaries.ai` as the intended stable iOS API hostname.
3. Make the website fully static only after the replacement iOS build is proven and old shared-host builds are no longer supported.
4. Remove the deployed Worker and repository-owned Node routing code at that point. Lighthouse CI may still use Node internally on an ephemeral CI runner; that is tooling, not a Node website runtime or backend.
5. Keep website CI deliberately small: Lighthouse CI, Lychee and the existing Worker tests only while the Worker exists.
6. Separate detection from remediation. CI tools determine pass or fail; an LLM may consume their structured reports to prepare a reviewed fix-forward change.
7. Do not introduce a persistent staging site for the current three-page, read-only website. Reconsider ephemeral previews when changes become interactive, visually risky, data-mutating or approval-dependent.

## Track A — Establish the Public-Site CI Baseline

Backlog item: `RH-021`.

### Sequence

1. Pin the selected Lighthouse and Lychee versions or immutable GitHub Action revisions. Recheck Lighthouse CI's bundled Lighthouse version: as of 2026-08-04, `@lhci/cli` 0.15.1 bundles Lighthouse 12.6.1 and therefore does not include the `llms.txt` audit added in Lighthouse 13.2. If that gap remains, use standalone Lighthouse 13.3 or later for this audit rather than inventing a repository-specific validator.
2. Run the existing Worker tests before deployment while `_worker.js` remains part of production.
3. Deploy the exact reviewed static assets and compatibility Worker to Cloudflare Pages from protected `main` using one serialised production workflow.
4. After deployment, run non-mutating checks against the canonical custom domain:
   - Lighthouse CI on `/`, `/support` and `/app-privacy-policy`;
   - Lychee with all three public page URLs supplied explicitly, plus `/robots.txt`, `/llms.txt` and `/health`; Lychee does not recursively crawl a live site.
5. Store native Lighthouse JSON/HTML and Lychee JSON/JUnit outputs as workflow artefacts.
6. On the first integrated run, preserve Lighthouse CI and Lychee as reporting checks so known findings do not prevent the CI plumbing itself from being integrated. Keep the existing Worker tests, deployment success and catastrophic public-page availability as blocking checks.
7. Record proposed stable routing, SEO, accessibility and best-practice assertions for promotion under `RH-022`. Keep performance advisory until repeated evidence supports a stable budget.
8. Mark the GitHub production deployment failed and notify only when a currently blocking post-deploy check fails. Keep Cloudflare's previous successful deployment available for manual rollback.
9. Do not automatically roll back for Lighthouse scores, latency, external-link failure or `/health`; those signals may be variable or owned by a different service.
10. If a deterministic deployment-owned catastrophic check is later added, design automatic rollback as a separate increment that captures the previous production deployment ID, serialises releases, verifies the failed deployment is still current and re-runs smoke checks after rollback.

### Initial 80/20 Evidence

- Existing Worker tests pass while the compatibility edge exists.
- All three public HTML pages produce retained Lighthouse CI reports.
- Lychee produces a retained explicit-URL report for all three pages and the public service files, with internal and external findings distinguishable.
- The reports capture the current `/robots.txt` and `/llms.txt` failures rather than hiding or pre-fixing them inside the CI setup increment.
- The exact native reports are retained and traceable to the deployed commit.

### Explicit Non-Goals

- No separate axe, Pa11y, PageSpeed Insights, WebPageTest, Observatory, TLS scanner or HTML validator unless baseline evidence exposes a gap that Lighthouse CI and Lychee cannot cover.
- No composite quality score that permits one category to hide a blocker in another.
- No LLM authority over CI pass/fail.

## Track B — Remediate the Baseline Reports

Backlog item: `RH-022`. Dependency: `RH-021` has produced a retained baseline report.

### Sequence

1. Preserve the first complete report set unchanged as the baseline.
2. Classify findings by route, owning source file, rule stability and whether the issue is deterministic or measurement-variable.
3. Fix deterministic failures first: public-file availability, broken links, invalid metadata, accessibility failures and stable Lighthouse best-practice or SEO audits.
4. Review performance findings separately. Change code only when the report identifies a reproducible cause; do not chase a single noisy score.
5. Re-run the same workflow and compare native reports with the baseline.
6. Use an LLM to interpret reports and prepare patches if useful, but require normal review and the unchanged deterministic gates before integration.
7. Do not lower a threshold or suppress a rule merely to obtain green CI. Record and approve any justified exception.
8. Promote the agreed stable assertions to blocking CI gates only after the baseline failures are corrected or explicitly accepted.
9. Finish with zero unresolved hard failures, explicitly accepted advisory findings and a concise record of residual risks.

## Track C — Split the API Host and Retire Compatibility Routing

Backlog item: `RH-020`. This is deferred until the current private-beta release path is stable.

### Phase 1 — Decide and prepare

1. Create or accept an ADR for the public-boundary change before implementation because it changes the iOS API contract, DNS and deployment ownership.
2. Inventory uploaded, processed and distributed builds that use `https://ridehorizon.digitalmercenaries.ai` as `FactProxyContract.productionBaseURL`.
3. Confirm the exact Fly application and current production origin. Reconcile stale documentation before changing DNS.
4. Define the compatibility window and the observable condition for retiring shared-host API routing.

### Phase 2 — Introduce the API hostname

1. Configure `api.ridehorizon.digitalmercenaries.ai` as a Fly custom domain using the verified Fly certificate and DNS procedure.
2. Verify TLS, `/health`, restricted session issuance, `/v1/fact` and `/v1/speech` through the new hostname without exposing credentials or request content.
3. Update the OpenAPI contract, human-readable contract, operational documentation and iOS endpoint together.
4. Build, test, archive and upload a replacement iOS candidate that uses the API subdomain.
5. Prove the exact processed build through Internal TestFlight before assigning it externally.

### Phase 3 — Hold compatibility

1. Keep the existing Cloudflare pass-through for shared-host builds during the accepted compatibility window.
2. Observe both hostnames and confirm supported testers have moved to the replacement build.
3. Stop if an active supported build still depends on shared-host API paths.

### Phase 4 — Make the website fully static

1. Restructure static assets so Cloudflare Pages can serve clean paths without `_worker.js`, for example `index.html`, `support/index.html` and `app-privacy-policy/index.html`.
2. Move static response headers into the platform's static `_headers` configuration.
3. Add `robots.txt` and `llms.txt` as ordinary static files; add a sitemap only when the publication policy requires it.
4. Remove Fly forwarding, `_worker.js` and its Node unit tests.
5. Choose the static deployment cutover explicitly. Cloudflare does not allow an existing Direct Upload Pages project to switch to Git integration. To remove the repository-owned Wrangler/npm deployment layer while retaining automated Git deployment, create a new Git-integrated static Pages project, verify its immutable Pages URL, then move the custom domain only after the API compatibility window closes. Dashboard drag-and-drop remains a manual alternative, not the intended CI path.
6. Do not claim that CI itself contains no Node-based third-party actions; the target is no repository-owned Node website runtime, Worker or deployment project.
7. Deploy and run the unchanged Lighthouse CI and Lychee post-deploy gates.
8. Verify shared-host API paths no longer form part of any supported public contract, then retire the compatibility route and old Direct Upload project through a separately verified, recoverable cutover.

## Gates

- `RH-021` may proceed independently when selected; it must not expand into general website redesign.
- `RH-022` starts only after a complete baseline report exists.
- `RH-020` starts only after the private-beta release gate is stable and Rob authorises DNS/API-contract work.
- Stop `RH-020` before compatibility removal if any supported build still uses the shared hostname.
- Stop before any secret, DNS, Fly certificate, Cloudflare production or App Store change that requires new authority or human account interaction.

## Sources

- [Cloudflare Pages Direct Upload with CI](https://developers.cloudflare.com/pages/how-to/use-direct-upload-with-continuous-integration/)
- [Cloudflare Pages Direct Upload project constraints](https://developers.cloudflare.com/pages/get-started/direct-upload/)
- [Cloudflare Pages preview deployments](https://developers.cloudflare.com/pages/configuration/preview-deployments/)
- [Cloudflare Pages rollbacks](https://developers.cloudflare.com/pages/configuration/rollbacks/)
- [Cloudflare Pages rollback API](https://developers.cloudflare.com/api/typescript/resources/pages/subresources/projects/subresources/deployments/methods/rollback)
- [Cloudflare Wrangler Action](https://github.com/cloudflare/wrangler-action)
- [GitHub deployment controls](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments)
- [Lighthouse CI configuration](https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/configuration.md)
- [Lighthouse 13.3 release](https://github.com/GoogleChrome/lighthouse/releases/tag/v13.3.0)
- [Lighthouse performance scoring variability](https://developer.chrome.com/docs/lighthouse/performance/performance-scoring)
- [Lychee](https://github.com/lycheeverse/lychee)
- [Fly custom domains](https://fly.io/docs/networking/custom-domain/)

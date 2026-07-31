# RideHorizon Cloudflare Edge Site

This Cloudflare Pages project serves the RideHorizon privacy policy and preserves the canonical proxy hostname.

- `GET` or `HEAD /app-privacy-policy` serves the static policy.
- `GET` or `HEAD /app-privacy-policy/` serves the same policy.
- Every other path is transparently forwarded to `https://motoguide-fact-proxy.fly.dev`, including `/health`, `/v1/session/*`, `/v1/fact`, and `/v1/speech`.
- The project contains no app or provider secret.

## Local verification

Run from `/Users/rob_dev/DocsLocal/motoguide/repo/privacy-site`.

1. Install the pinned development tools: `npm ci`

   Expected result: npm installs the exact locked dependencies without modifying `package-lock.json`.

2. Run the edge-router tests: `npm test`

   Expected result: all privacy-path, method, proxy-body, and upstream-failure tests pass.

3. Start a local preview if needed: `npm run dev`

   Expected result: Wrangler prints a local URL, normally `http://localhost:8787`.

## First deployment

1. Authenticate with Cloudflare: `npx wrangler login`

   Expected result: the browser sign-in completes and Wrangler reports that login succeeded.

2. Create the Pages project once: `npx wrangler pages project create ridehorizon-edge --production-branch main --compatibility-date 2026-07-31`

   Expected result: Cloudflare creates `ridehorizon-edge.pages.dev`.

3. Deploy the policy and edge router: `npm run deploy`

   Expected result: Wrangler reports a successful production deployment and a `pages.dev` URL.

4. In Cloudflare, open **Workers & Pages > ridehorizon-edge > Custom domains > Set up a domain** and add `ridehorizon.digitalmercenaries.ai` before changing DNS.

   Expected result: Cloudflare shows the custom domain as pending and expects a CNAME to the Pages project.

5. In Namecheap Advanced DNS, create this record:

   - Type: `CNAME Record`
   - Host: `ridehorizon`
   - Value: `ridehorizon-edge.pages.dev`
   - TTL: `Automatic`

   There is currently no `ridehorizon` record to remove. Do not change the domain's nameservers, MX records, or other DNS records.

6. Wait for Cloudflare to show the custom domain as active, then verify: `curl -I https://ridehorizon.digitalmercenaries.ai/app-privacy-policy`

   Expected result: HTTP 200 with `content-type: text/html; charset=utf-8`.

7. Verify that the canonical proxy hostname still reaches Fly: `curl -fsS https://ridehorizon.digitalmercenaries.ai/health`

   Expected result: `ok`.

8. Repeat the automatic-session and speech smoke test through the canonical hostname before changing the iOS compatibility flag.

## Updates and rollback

Publish a content or routing update with `npm test && npm run deploy`.

Expected result: tests pass before Wrangler creates the production deployment. Cloudflare Pages retains previous deployments for rollback in the dashboard.

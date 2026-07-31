const FLY_ORIGIN = "https://motoguide-fact-proxy.fly.dev";
const POLICY_PATHS = new Set(["/app-privacy-policy", "/app-privacy-policy/"]);

const POLICY_HEADERS = {
  "Cache-Control": "public, max-age=300",
  "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; upgrade-insecure-requests",
  "Permissions-Policy": "accelerometer=(), camera=(), geolocation=(), gyroscope=(), microphone=(), payment=(), usb=()",
  "Referrer-Policy": "no-referrer",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY"
};

async function servePrivacyPolicy(request, env) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: { Allow: "GET, HEAD", "Cache-Control": "no-store" }
    });
  }

  const assetURL = new URL("/index.html", request.url);
  const assetRequest = new Request(assetURL, {
    method: request.method,
    headers: request.headers
  });
  const assetResponse = await env.ASSETS.fetch(assetRequest);
  const headers = new Headers(assetResponse.headers);

  for (const [name, value] of Object.entries(POLICY_HEADERS)) {
    headers.set(name, value);
  }
  headers.set("Content-Type", "text/html; charset=utf-8");

  return new Response(request.method === "HEAD" ? null : assetResponse.body, {
    status: assetResponse.status,
    statusText: assetResponse.statusText,
    headers
  });
}

async function proxyToFly(request, originFetch) {
  const incomingURL = new URL(request.url);
  const upstreamURL = new URL(incomingURL.pathname + incomingURL.search, FLY_ORIGIN);

  try {
    return await originFetch(new Request(upstreamURL, request));
  } catch {
    return new Response("Bad Gateway", {
      status: 502,
      headers: {
        "Cache-Control": "no-store",
        "Content-Type": "text/plain; charset=utf-8"
      }
    });
  }
}

export async function handleRequest(request, env, originFetch = fetch) {
  const { pathname } = new URL(request.url);

  if (POLICY_PATHS.has(pathname)) {
    return servePrivacyPolicy(request, env);
  }

  return proxyToFly(request, originFetch);
}

export default {
  async fetch(request, env) {
    return handleRequest(request, env);
  }
};

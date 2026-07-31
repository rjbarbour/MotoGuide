import assert from "node:assert/strict";
import test from "node:test";

import { handleRequest } from "../site/_worker.js";

function assetsEnvironment() {
  const calls = [];
  return {
    calls,
    env: {
      ASSETS: {
        async fetch(request) {
          calls.push(request);
          return new Response("<!doctype html><title>RideHorizon Privacy Policy</title>", {
            headers: { "Content-Type": "text/html" }
          });
        }
      }
    }
  };
}

test("serves the exact privacy path as secured HTML", async () => {
  const { env, calls } = assetsEnvironment();
  const response = await handleRequest(
    new Request("https://ridehorizon.digitalmercenaries.ai/app-privacy-policy"),
    env,
    async () => assert.fail("privacy requests must not reach Fly")
  );

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Content-Type"), "text/html; charset=utf-8");
  assert.equal(response.headers.get("X-Frame-Options"), "DENY");
  assert.match(response.headers.get("Content-Security-Policy"), /default-src 'none'/);
  assert.match(await response.text(), /RideHorizon Privacy Policy/);
  assert.equal(calls.length, 1);
  assert.equal(new URL(calls[0].url).pathname, "/index.html");
});

test("accepts the trailing-slash privacy path and supports HEAD", async () => {
  const { env, calls } = assetsEnvironment();
  const response = await handleRequest(
    new Request("https://ridehorizon.digitalmercenaries.ai/app-privacy-policy/", { method: "HEAD" }),
    env
  );

  assert.equal(response.status, 200);
  assert.equal(await response.text(), "");
  assert.equal(calls[0].method, "HEAD");
});

test("rejects writes to the privacy path", async () => {
  const { env, calls } = assetsEnvironment();
  const response = await handleRequest(
    new Request("https://ridehorizon.digitalmercenaries.ai/app-privacy-policy", { method: "POST" }),
    env
  );

  assert.equal(response.status, 405);
  assert.equal(response.headers.get("Allow"), "GET, HEAD");
  assert.equal(calls.length, 0);
});

test("proxies API requests to Fly without consuming the request body", async () => {
  const { env } = assetsEnvironment();
  let upstreamRequest;
  const response = await handleRequest(
    new Request("https://ridehorizon.digitalmercenaries.ai/v1/speech?format=mp3", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-session",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ text: "Hello from RideHorizon" })
    }),
    env,
    async request => {
      upstreamRequest = request;
      return new Response(new Uint8Array([0x49, 0x44, 0x33]), {
        headers: { "Content-Type": "audio/mpeg" }
      });
    }
  );

  assert.equal(upstreamRequest.url, "https://motoguide-fact-proxy.fly.dev/v1/speech?format=mp3");
  assert.equal(upstreamRequest.method, "POST");
  assert.equal(upstreamRequest.headers.get("Authorization"), "Bearer test-session");
  assert.deepEqual(await upstreamRequest.json(), { text: "Hello from RideHorizon" });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Content-Type"), "audio/mpeg");
});

test("proxies non-policy paths and returns a controlled upstream failure", async () => {
  const { env } = assetsEnvironment();
  const response = await handleRequest(
    new Request("https://ridehorizon.digitalmercenaries.ai/health"),
    env,
    async () => {
      throw new Error("origin unavailable");
    }
  );

  assert.equal(response.status, 502);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(await response.text(), "Bad Gateway");
});

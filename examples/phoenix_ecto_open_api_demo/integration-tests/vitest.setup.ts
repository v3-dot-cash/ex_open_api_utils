import { beforeAll } from "vitest";

import { client } from "./generated/client.gen";

// Phoenix base URL — the Makefile sets VITEST_BASE_URL before invoking
// vitest. Default to localhost:4100 so plain `npm run test` works after
// the server is up, without needing env flags.
const baseUrl = process.env.VITEST_BASE_URL ?? "http://localhost:4100";

// Configure the generated ky client once for all tests.
//
// Test-tier deliberate divergence from production: retries disabled.
// In a production client we'd have ky retry idempotent requests on
// transient 5xx and network failures. In the test tier we want failures
// to be loud and immediate — a silently-retried bug is worse than a
// fast failure. Every other ky config option matches what a production
// client would use.
client.setConfig({
  baseUrl,
  retry: { limit: 0 },
});

// Fail fast if Phoenix isn't reachable. The Makefile already polls
// /api/openapi before invoking vitest, but this guard catches the
// `npm run test` direct path too so the first failing test gives an
// actionable error instead of a storm of connection-refused noise.
beforeAll(async () => {
  try {
    const res = await fetch(`${baseUrl}/api/openapi`);
    if (!res.ok) {
      throw new Error(
        `Phoenix health check at ${baseUrl}/api/openapi returned ${res.status}`,
      );
    }
  } catch (err) {
    throw new Error(
      `Cannot reach Phoenix at ${baseUrl}. Is "make vitest" running?\n` +
        `Underlying error: ${(err as Error).message}`,
    );
  }
});

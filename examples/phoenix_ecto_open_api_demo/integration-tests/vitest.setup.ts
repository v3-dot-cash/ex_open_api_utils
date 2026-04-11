import { client } from "@hey-api/client-fetch";
import { beforeAll } from "vitest";

// Phoenix base URL — the Makefile sets VITEST_BASE_URL before invoking
// vitest. Default to localhost:4100 so plain `npm run test` works after
// the server is up, without needing env flags.
const baseUrl = process.env.VITEST_BASE_URL ?? "http://localhost:4100";

// Configure the hey-api fetch client once for all tests. Individual test
// files can still override baseUrl per call via options.
client.setConfig({ baseUrl });

// Fail fast if Phoenix isn't reachable — the Makefile waits for the
// /api/openapi endpoint before invoking vitest, but in the direct
// `npm run test` path we guard here too so the first failing test gives
// an actionable error rather than 30+ connection-refused errors.
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

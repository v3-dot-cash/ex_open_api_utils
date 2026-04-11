import { heyApiPlugin } from "@hey-api/vite-plugin";
import { defineConfig } from "vitest/config";

/**
 * Vitest config for the local integration tier.
 *
 * The @hey-api/vite-plugin wraps the openapi-ts generator and runs it
 * automatically at vitest startup against the spec that `mix openapi.dump`
 * wrote to priv/static/openapi.json. The plugin regenerates the SDK into
 * ./generated on every vitest invocation so there's no separate
 * generate-sdk Makefile step.
 *
 * The plugin list below is the exact production stack we recommend for
 * real consumers: ky HTTP client, typescript types, typed SDK functions,
 * JSON schema re-exports, and zod runtime validators. The vitest tier
 * mirrors this verbatim so tests exercise the same surface a production
 * client would — the only deliberate divergence is retries, disabled at
 * runtime in vitest.setup.ts so failures surface loudly instead of
 * retrying into success.
 */
export default defineConfig({
  plugins: [
    heyApiPlugin({
      config: {
        input: "../priv/static/openapi.json",
        output: "./generated",
        plugins: [
          "@hey-api/client-ky",
          "@hey-api/typescript",
          "@hey-api/sdk",
          "@hey-api/schemas",
          "zod",
        ],
      },
    }),
  ],
  test: {
    globals: true,
    environment: "node",
    setupFiles: ["./vitest.setup.ts"],
    // Sequential runs — the Makefile bounces a single Postgres + Phoenix
    // pair with no sandbox transaction; parallel tests would race on
    // shared DB state.
    fileParallelism: false,
    testTimeout: 10_000,
  },
});

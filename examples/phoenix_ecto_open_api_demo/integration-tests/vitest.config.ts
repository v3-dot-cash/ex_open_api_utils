import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    setupFiles: ["./vitest.setup.ts"],
    // Run tests sequentially, one file at a time. The Makefile bounces a
    // single Postgres + Phoenix pair; parallel tests would race on shared
    // DB state with no sandbox transaction.
    fileParallelism: false,
    pool: "forks",
    poolOptions: {
      forks: { singleFork: true },
    },
    testTimeout: 10_000,
  },
});

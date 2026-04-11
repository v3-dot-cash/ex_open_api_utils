# PhoenixEctoOpenApiDemo

Reference app for `ex_open_api_utils` — exercises every supported
pattern against a real Phoenix + Ecto surface, with a local vitest HTTP
integration tier for end-to-end SDK validation.

## Running the Phoenix server

  * `mix setup` — install deps, create the DB, run migrations
  * `mix phx.server` — start on [http://localhost:4000](http://localhost:4000)
  * `iex -S mix phx.server` — same, with an IEx shell attached

## Running the Elixir test suite

```
mix test
```

Covers controllers, contexts, and the full cast/round-trip flow for
every resource. These are the load-bearing tests — if they pass, the
library contract against this example is intact.

## Running the vitest integration tier (local only)

The vitest tier stands up a dedicated Phoenix + Postgres pair, generates
a typed TypeScript SDK from the live OpenAPI spec via hey-api, and runs
end-to-end HTTP tests against it. Not wired into CI — it's a local
development aid that proves the spec → SDK → wire round-trip works
against a real server, not just `Plug.Test`.

### Prerequisites

  * Docker + Docker Compose (for tmpfs Postgres)
  * Node.js 20+ (for vitest and hey-api)

### Running

```
make vitest
```

Full sequence:

  1. tears down any leftover vitest container
  2. brings up a fresh tmpfs Postgres on port 5433
  3. runs `mix ecto.reset` against it
  4. syncs `integration-tests/package.json` version to `mix.exs`
  5. runs `mix openapi.dump` and feeds the spec to hey-api, emitting a
     typed client into `integration-tests/generated/`
  6. starts Phoenix on port 4100 in the background
  7. polls `/api/openapi` until the server is ready
  8. runs the vitest suite under `integration-tests/tests/`
  9. tears the container down on exit (pass or fail)

### Port and version overrides

All overridable via env:

```
VITEST_POSTGRES_PORT=5433   # Postgres bind port (default 5433)
VITEST_PHOENIX_PORT=4100    # Phoenix HTTP port (default 4100)
HEY_API_VERSION=0.95.0      # pinned hey-api version (default 0.95.0)
```

### Scope

Two test files under `integration-tests/tests/`:

  * `notifications.test.ts` — GH-30 HTTP regression lock. POSTs each
    polymorphic channel variant (email/sms/webhook), asserts the
    response body preserves `channel_type` on the channel sub-object.
    Rounds through GET and PUT to catch direction-specific regressions.
  * `crud.test.ts` — minimal CRUD smoke for the non-polymorphic
    resources (tenants, users, businesses). Deep assertions for those
    live in the Elixir `mix test` suites; this is a wire-level sanity
    check only.

Client samples under `client_samples/typescript/notifications/` show how
to construct each variant's request body and how to narrow a response
via its `channel_type` discriminant.

## Learn more

  * `ex_open_api_utils`: https://hex.pm/packages/ex_open_api_utils
  * Phoenix framework: https://www.phoenixframework.org/
  * hey-api: https://heyapi.dev/

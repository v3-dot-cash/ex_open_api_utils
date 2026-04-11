# Makefile for the local vitest HTTP integration tier.
#
# This tier bounces a dedicated Postgres (tmpfs) + Phoenix pair, dumps
# the OpenAPI spec, generates a TypeScript SDK via hey-api, then runs
# vitest tests against the live HTTP surface. All ports and versions
# are overridable via env vars and default to values that won't collide
# with a contributor's existing dev setup.
#
# Not wired into CI. Only use via `make vitest` locally.

# Ports — overridable. Defaults chosen to not collide with default
# Postgres (5432) or Phoenix (4000) dev ports.
VITEST_POSTGRES_PORT ?= 5433
VITEST_PHOENIX_PORT ?= 4100

# Pinned hey-api version resolved via `npm view @hey-api/openapi-ts version`
# at implementation time. Bump when upgrading.
HEY_API_VERSION ?= 0.95.0

# Resolved from the app's mix.exs project version line. The
# vitest-sync-versions target pushes this into integration-tests/package.json
# so the SDK client and the Elixir app always advertise the same version
# string to tests.
APP_VERSION := $(shell sed -n 's/.*version: "\([^"]*\)".*/\1/p' mix.exs | head -1)

.PHONY: vitest vitest-up vitest-down vitest-sync-versions \
        vitest-generate-sdk vitest-server vitest-wait-server vitest-run

# Top-level entry point. Full happy-path sequence:
#   1. bring up tmpfs Postgres
#   2. reset the app's ecto DB against it
#   3. sync the integration-tests package version to mix.exs
#   4. dump the OpenAPI spec and generate the hey-api SDK
#   5. start Phoenix on the dedicated port in the background
#   6. wait for the server to respond
#   7. run vitest
#   8. tear everything down on exit (trap handles both pass and fail)
vitest: vitest-down vitest-up
	MIX_ENV=dev \
	PGHOST=localhost \
	PGPORT=$(VITEST_POSTGRES_PORT) \
	PGUSER=postgres \
	PGPASSWORD=postgres \
	mix ecto.reset
	$(MAKE) vitest-sync-versions
	$(MAKE) vitest-generate-sdk
	@trap '$(MAKE) vitest-down' EXIT INT TERM; \
	 $(MAKE) vitest-server & \
	 SERVER_PID=$$!; \
	 trap "kill $$SERVER_PID 2>/dev/null; $(MAKE) vitest-down" EXIT INT TERM; \
	 $(MAKE) vitest-wait-server && \
	 $(MAKE) vitest-run

vitest-up:
	docker compose -f docker-compose.test.yml up -d --wait

vitest-down:
	-docker compose -f docker-compose.test.yml down -v 2>/dev/null

# Push mix.exs project version into integration-tests/package.json so the
# TypeScript side always reports the same version as the Elixir side.
vitest-sync-versions:
	@cd integration-tests && \
	 node -e "const fs=require('fs'); const p=require('./package.json'); p.version='$(APP_VERSION)'; fs.writeFileSync('package.json', JSON.stringify(p,null,2)+'\n');"
	@echo "integration-tests/package.json version synced to $(APP_VERSION)"

# Dump the OpenAPI spec to priv/static/openapi.json, then run hey-api
# against it to emit a typed TypeScript client into
# integration-tests/generated/. Pinned to HEY_API_VERSION via npx so
# contributors don't accidentally drift.
vitest-generate-sdk:
	mix openapi.dump
	cd integration-tests && \
	 npx --yes @hey-api/openapi-ts@$(HEY_API_VERSION) \
	   --input ../priv/static/openapi.json \
	   --output generated \
	   --client @hey-api/client-fetch

# Start Phoenix in the foreground against the tmpfs Postgres, on the
# dedicated VITEST_PHOENIX_PORT. The vitest target backgrounds this and
# traps on exit.
vitest-server:
	MIX_ENV=dev \
	PORT=$(VITEST_PHOENIX_PORT) \
	PGHOST=localhost \
	PGPORT=$(VITEST_POSTGRES_PORT) \
	PGUSER=postgres \
	PGPASSWORD=postgres \
	mix phx.server

# Poll the openapi spec endpoint until Phoenix is responding. Times out
# after ~30s so a stuck server doesn't hang CI-style invocations.
vitest-wait-server:
	@echo "Waiting for Phoenix on port $(VITEST_PHOENIX_PORT)..."
	@for i in $$(seq 1 60); do \
	  if curl -sf http://localhost:$(VITEST_PHOENIX_PORT)/api/openapi > /dev/null 2>&1; then \
	    echo "Phoenix ready"; \
	    exit 0; \
	  fi; \
	  sleep 0.5; \
	done; \
	echo "Phoenix did not start within 30s"; \
	exit 1

# Actually run the vitest suite. Install deps first (idempotent, npm
# skips if lockfile + node_modules are already in sync).
vitest-run:
	cd integration-tests && \
	 VITEST_BASE_URL=http://localhost:$(VITEST_PHOENIX_PORT) \
	 npm install && \
	 npm run test

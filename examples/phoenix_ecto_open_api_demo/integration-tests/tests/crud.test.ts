import { client } from "@hey-api/client-fetch";
import { describe, expect, test } from "vitest";

/**
 * Minimal CRUD smoke tests for the non-polymorphic resources (tenants,
 * users, businesses). These don't exercise the GH-30 fix — they exist
 * to prove the vitest tier itself is wired up correctly and that
 * non-polymorphic resources still work alongside the Notification fix.
 *
 * Deep assertions on each resource's full response shape live in the
 * Elixir `mix test` controller suites; this file intentionally stops
 * at "the create returned 201 and the list returned 200".
 */

describe.each([
  { resource: "tenants", name: "some test tenant" },
  { resource: "users", name: "some test user" },
  { resource: "businesses", name: "some test business" },
])("$resource CRUD smoke", ({ resource, name }) => {
  test(`POST /api/${resource} creates the resource`, async () => {
    const { data, error, response } = await client.post<{ id: string; name: string }>({
      url: `/api/${resource}`,
      body: { name },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);
    expect(data!.id).toBeTruthy();
    expect(data!.name).toBe(name);
  });

  test(`GET /api/${resource} returns a list`, async () => {
    const { error, response } = await client.get<Array<{ id: string }>>({
      url: `/api/${resource}`,
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(200);
  });
});

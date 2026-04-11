import { describe, expect, test } from "vitest";

import {
  businessCreate,
  businessList,
  tenantCreate,
  tenantList,
  userCreate,
  userList,
} from "../generated/sdk.gen";

/**
 * Minimal CRUD smoke tests for the non-polymorphic resources. These
 * don't exercise the GH-30 fix — they exist to prove the vitest tier
 * itself is wired correctly and that non-polymorphic resources still
 * work alongside the Notification fix.
 *
 * Uses the typed SDK functions from @hey-api/sdk so request bodies
 * and response shapes are type-checked at compile time. Deep
 * assertions on each resource's full response shape still live in
 * the Elixir `mix test` controller suites; this file intentionally
 * stops at "the create returned 201 and the list returned 200".
 */

describe("tenant CRUD smoke", () => {
  test("tenantCreate then tenantList", async () => {
    const { data: created, error: createError, response: createResponse } =
      await tenantCreate({ body: { name: "some test tenant" } });

    expect(createError).toBeUndefined();
    expect(createResponse.status).toBe(201);
    expect(created!.id).toBeTruthy();
    expect(created!.name).toBe("some test tenant");

    const { error: listError, response: listResponse } = await tenantList();
    expect(listError).toBeUndefined();
    expect(listResponse.status).toBe(200);
  });
});

describe("user CRUD smoke", () => {
  test("userCreate then userList", async () => {
    const { data: created, error: createError, response: createResponse } =
      await userCreate({ body: { name: "some test user" } });

    expect(createError).toBeUndefined();
    expect(createResponse.status).toBe(201);
    expect(created!.id).toBeTruthy();
    expect(created!.name).toBe("some test user");

    const { error: listError, response: listResponse } = await userList();
    expect(listError).toBeUndefined();
    expect(listResponse.status).toBe(200);
  });
});

describe("business CRUD smoke", () => {
  test("businessCreate then businessList", async () => {
    const { data: created, error: createError, response: createResponse } =
      await businessCreate({ body: { name: "some test business" } });

    expect(createError).toBeUndefined();
    expect(createResponse.status).toBe(201);
    expect(created!.id).toBeTruthy();
    expect(created!.name).toBe("some test business");

    const { error: listError, response: listResponse } = await businessList();
    expect(listError).toBeUndefined();
    expect(listResponse.status).toBe(200);
  });
});

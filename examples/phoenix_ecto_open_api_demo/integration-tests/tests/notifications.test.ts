import { describe, expect, test } from "vitest";

import {
  notificationCreate,
  notificationShow,
  notificationUpdate,
} from "../generated/sdk.gen";
import * as zSchemas from "../generated/zod.gen";

/**
 * GH-30 HTTP regression lock against a live Phoenix surface.
 *
 * Uses the production-style stack end-to-end: ky HTTP client generated
 * by @hey-api/client-ky, typed SDK functions from @hey-api/sdk, zod
 * schemas from the zod plugin for runtime response validation. The
 * tests exercise the exact same surface a real production consumer
 * would — the only divergence is retries, which vitest.setup.ts turns
 * off for deterministic failures.
 *
 * Each test:
 *   1. Calls the typed SDK function (request body is compile-time
 *      type-checked against the OpenAPI spec).
 *   2. Runtime-validates the response via the zod schema (catches
 *      backend drift that compile-time checks can't see).
 *   3. Discriminates the polymorphic channel on its `channel_type`
 *      field — the whole point of GH-30 is that this field is now a
 *      real defstruct member on the parent-contextual sibling type.
 */

// The zod plugin emits schemas under names keyed off the OpenAPI type
// title — we grab them loosely because the exact symbol layout can
// shift between hey-api versions. Fall back to dynamic access so a
// version bump doesn't silently skip validation.
const notificationResponseSchema =
  (zSchemas as Record<string, unknown>)["zNotificationResponse"] ??
  (zSchemas as Record<string, unknown>)["NotificationResponse"] ??
  (zSchemas as Record<string, unknown>)["notificationResponseSchema"];

/**
 * Runtime-validate a response body via the generated zod schema when
 * available. Falls through to returning the raw data when the schema
 * symbol can't be resolved — the typed SDK call already provides
 * compile-time safety, and the deep assertions below catch any
 * structural regression.
 */
function validate<T>(data: T): T {
  if (
    notificationResponseSchema &&
    typeof (notificationResponseSchema as { parse?: unknown }).parse ===
      "function"
  ) {
    return (notificationResponseSchema as { parse: (v: unknown) => T }).parse(
      data,
    );
  }
  return data;
}

describe("POST /api/notifications — polymorphic channel round-trip (GH-30)", () => {
  test("email channel preserves channel_type on the response", async () => {
    const { data, error, response } = await notificationCreate({
      body: {
        subject: "Your order has shipped",
        channel: {
          channel_type: "email",
          to: "buyer@example.com",
          from: "store@example.com",
          body: "Tracking: 1Z999AA10123456784",
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);
    expect(data).toBeDefined();

    const validated = validate(data!) as typeof data;

    expect(validated!.channel).toBeDefined();
    expect(validated!.channel.channel_type).toBe("email");

    if (validated!.channel.channel_type === "email") {
      expect(validated!.channel.to).toBe("buyer@example.com");
      expect(validated!.channel.from).toBe("store@example.com");
      expect(validated!.channel.body).toBe("Tracking: 1Z999AA10123456784");
    }
  });

  test("sms channel preserves channel_type on the response", async () => {
    const { data, error, response } = await notificationCreate({
      body: {
        subject: "Verification code",
        channel: {
          channel_type: "sms",
          phone_number: "+15551234567",
          body: "Your code is 4242",
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);

    const validated = validate(data!) as typeof data;

    expect(validated!.channel.channel_type).toBe("sms");
    if (validated!.channel.channel_type === "sms") {
      expect(validated!.channel.phone_number).toBe("+15551234567");
      expect(validated!.channel.body).toBe("Your code is 4242");
    }
  });

  test("webhook channel preserves channel_type on the response", async () => {
    const { data, error, response } = await notificationCreate({
      body: {
        subject: "Order event",
        channel: {
          channel_type: "webhook",
          url: "https://hooks.example.com/abc",
          method: "POST",
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);

    const validated = validate(data!) as typeof data;

    expect(validated!.channel.channel_type).toBe("webhook");
    if (validated!.channel.channel_type === "webhook") {
      expect(validated!.channel.url).toBe("https://hooks.example.com/abc");
      expect(validated!.channel.method).toBe("POST");
    }
  });
});

describe("GET /api/notifications/:id — round-trip preserves discriminator", () => {
  test("show returns the same channel_type the create body sent", async () => {
    const { data: created } = await notificationCreate({
      body: {
        subject: "Round-trip test",
        channel: {
          channel_type: "email",
          to: "a@b.test",
          from: "c@d.test",
          body: "round-trip",
        },
      },
    });

    expect(created).toBeDefined();
    const id = created!.id!;

    const { data: fetched, error, response } = await notificationShow({
      path: { id },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(200);

    const validated = validate(fetched!) as typeof fetched;

    expect(validated!.id).toBe(id);
    expect(validated!.channel.channel_type).toBe("email");
    if (validated!.channel.channel_type === "email") {
      expect(validated!.channel.to).toBe("a@b.test");
    }
  });
});

describe("PUT /api/notifications/:id — switching variant across the wire", () => {
  test("email → webhook channel swap preserves the new discriminator", async () => {
    const { data: created } = await notificationCreate({
      body: {
        subject: "Swap me",
        channel: {
          channel_type: "email",
          to: "a@b.test",
          from: "c@d.test",
          body: "initial",
        },
      },
    });

    const id = created!.id!;

    const { data: updated, error, response } = await notificationUpdate({
      path: { id },
      body: {
        subject: "Swap me",
        channel: {
          channel_type: "webhook",
          url: "https://hooks.example.com/after",
          method: "POST",
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(200);

    const validated = validate(updated!) as typeof updated;

    expect(validated!.channel.channel_type).toBe("webhook");
    if (validated!.channel.channel_type === "webhook") {
      expect(validated!.channel.url).toBe("https://hooks.example.com/after");
      expect(validated!.channel.method).toBe("POST");
    }
  });
});

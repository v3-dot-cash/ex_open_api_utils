import { describe, expect, test } from "vitest";

import {
  subscriptionCreate,
  subscriptionShow,
} from "../generated/sdk.gen";
import * as zSchemas from "../generated/zod.gen";

/**
 * GH-34 HTTP regression lock against a live Phoenix surface.
 *
 * Exercises the nested polymorphic shape end-to-end through the same
 * production-style stack as notifications.test.ts: ky HTTP client from
 * @hey-api/client-ky, typed SDK functions from @hey-api/sdk, zod schemas
 * from the zod plugin for runtime response validation. The tests match
 * the example app's 3-level subscription tree:
 *
 *   Subscription (level 0)
 *   ├── :destination — polymorphic [webhook, email]
 *   │
 *   ├── WebhookDestination (level 1)
 *   │   └── :auth — polymorphic [oauth, basic]
 *   │       │
 *   │       ├── OAuthAuth (level 2)
 *   │       │   └── :grant — polymorphic [client_credentials, authorization_code]
 *   │       │       │
 *   │       │       ├── ClientCredentialsGrant (level 3 leaf)
 *   │       │       └── AuthorizationCodeGrant (level 3 leaf)
 *   │       │
 *   │       └── BasicAuth (level 2 leaf)
 *   │
 *   └── EmailDestination (level 1 leaf)
 *
 * Before 0.15.0, any request with nesting depth >= 2 raised
 * `PolymorphicEmbed.raise_cannot_infer_type_from_data/1` on the Phoenix
 * side, surfacing to the client as a 500 (or 422, depending on the
 * FallbackController). After the self-stamping parent-contextual sibling
 * Mapper impls land, every depth routes cleanly through the changeset.
 */

// The zod plugin emits schemas under names keyed off the OpenAPI type
// title. Grab loosely because the exact symbol layout can shift between
// hey-api versions — fall back to dynamic access so a version bump
// doesn't silently skip validation.
const subscriptionResponseSchema =
  (zSchemas as Record<string, unknown>)["zSubscriptionResponse"] ??
  (zSchemas as Record<string, unknown>)["SubscriptionResponse"] ??
  (zSchemas as Record<string, unknown>)["subscriptionResponseSchema"];

function validate<T>(data: T): T {
  if (
    subscriptionResponseSchema &&
    typeof (subscriptionResponseSchema as { parse?: unknown }).parse ===
      "function"
  ) {
    return (
      subscriptionResponseSchema as { parse: (v: unknown) => T }
    ).parse(data);
  }
  return data;
}

describe("POST /api/subscriptions — nesting depth 3 (webhook → oauth → client_credentials)", () => {
  test("three stacked discriminators survive the full HTTP round-trip", async () => {
    const { data, error, response } = await subscriptionCreate({
      body: {
        name: "Order events subscription",
        destination: {
          destination_type: "webhook",
          url: "https://hooks.example.com/orders",
          method: "POST",
          auth: {
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-abc-123",
            grant: {
              grant_type: "client_credentials",
              client_secret: "sk-example-secret",
              scope: "read:events write:webhooks",
            },
          },
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);
    expect(data).toBeDefined();

    const validated = validate(data!) as typeof data;

    // Level 1 discriminator
    expect(validated!.destination.destination_type).toBe("webhook");

    // Level 2 discriminator — this is the GH-34 gap
    if (validated!.destination.destination_type === "webhook") {
      expect(validated!.destination.url).toBe(
        "https://hooks.example.com/orders",
      );
      expect(validated!.destination.method).toBe("POST");
      expect(validated!.destination.auth.auth_type).toBe("oauth");

      // Level 3 discriminator — depth-unbounded after the fix
      if (validated!.destination.auth.auth_type === "oauth") {
        expect(validated!.destination.auth.token_url).toBe(
          "https://auth.example.com/oauth/token",
        );
        expect(validated!.destination.auth.client_id).toBe("client-abc-123");
        expect(validated!.destination.auth.grant.grant_type).toBe(
          "client_credentials",
        );

        if (
          validated!.destination.auth.grant.grant_type ===
          "client_credentials"
        ) {
          expect(validated!.destination.auth.grant.scope).toBe(
            "read:events write:webhooks",
          );
        }
      }
    }
  });
});

describe("POST /api/subscriptions — nesting depth 3 (webhook → oauth → authorization_code)", () => {
  test("alternate level-3 grant variant routes through the same chain", async () => {
    const { data, error, response } = await subscriptionCreate({
      body: {
        name: "Authz-code subscription",
        destination: {
          destination_type: "webhook",
          url: "https://hooks.example.com/authz",
          method: "POST",
          auth: {
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-zzz-789",
            grant: {
              grant_type: "authorization_code",
              authorization_code: "ac_example_code",
              redirect_uri: "https://app.example.com/oauth/callback",
            },
          },
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);

    const validated = validate(data!) as typeof data;

    expect(validated!.destination.destination_type).toBe("webhook");
    if (validated!.destination.destination_type === "webhook") {
      expect(validated!.destination.auth.auth_type).toBe("oauth");

      if (validated!.destination.auth.auth_type === "oauth") {
        expect(validated!.destination.auth.grant.grant_type).toBe(
          "authorization_code",
        );

        if (
          validated!.destination.auth.grant.grant_type ===
          "authorization_code"
        ) {
          expect(validated!.destination.auth.grant.redirect_uri).toBe(
            "https://app.example.com/oauth/callback",
          );
        }
      }
    }
  });
});

describe("POST /api/subscriptions — nesting depth 2 (webhook → basic)", () => {
  test("two stacked discriminators route correctly, terminates at BasicAuth leaf", async () => {
    const { data, error, response } = await subscriptionCreate({
      body: {
        name: "Infra alerts",
        destination: {
          destination_type: "webhook",
          url: "https://hooks.example.com/infra",
          method: "POST",
          auth: {
            auth_type: "basic",
            username: "alice",
            password: "s3cret",
          },
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);

    const validated = validate(data!) as typeof data;

    expect(validated!.destination.destination_type).toBe("webhook");
    if (validated!.destination.destination_type === "webhook") {
      expect(validated!.destination.auth.auth_type).toBe("basic");

      if (validated!.destination.auth.auth_type === "basic") {
        expect(validated!.destination.auth.username).toBe("alice");
      }
    }
  });
});

describe("POST /api/subscriptions — nesting depth 1 (flat email)", () => {
  test("0.14.0 single-level parity regression lock", async () => {
    const { data, error, response } = await subscriptionCreate({
      body: {
        name: "Ops digest",
        destination: {
          destination_type: "email",
          recipient: "ops@example.com",
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);

    const validated = validate(data!) as typeof data;

    expect(validated!.destination.destination_type).toBe("email");
    if (validated!.destination.destination_type === "email") {
      expect(validated!.destination.recipient).toBe("ops@example.com");
    }
  });
});

describe("GET /api/subscriptions/:id — 3-level nested round-trip preserves all discriminators", () => {
  test("show returns the same discriminators the create body sent at every nesting level", async () => {
    const { data: created } = await subscriptionCreate({
      body: {
        name: "Round-trip nested test",
        destination: {
          destination_type: "webhook",
          url: "https://hooks.example.com/roundtrip",
          method: "POST",
          auth: {
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-roundtrip",
            grant: {
              grant_type: "client_credentials",
              client_secret: "sk-roundtrip-secret",
              scope: "read:events",
            },
          },
        },
      },
    });

    expect(created).toBeDefined();
    const id = created!.id!;

    const {
      data: fetched,
      error,
      response,
    } = await subscriptionShow({ path: { id } });

    expect(error).toBeUndefined();
    expect(response.status).toBe(200);

    const validated = validate(fetched!) as typeof fetched;

    expect(validated!.id).toBe(id);
    expect(validated!.destination.destination_type).toBe("webhook");

    if (validated!.destination.destination_type === "webhook") {
      expect(validated!.destination.auth.auth_type).toBe("oauth");

      if (validated!.destination.auth.auth_type === "oauth") {
        expect(validated!.destination.auth.grant.grant_type).toBe(
          "client_credentials",
        );
      }
    }
  });
});

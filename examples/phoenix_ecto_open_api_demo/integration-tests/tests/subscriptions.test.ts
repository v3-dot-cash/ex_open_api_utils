import { describe, expect, test } from "vitest";

import {
  subscriptionCreate,
  subscriptionShow,
  subscriptionShowStruct,
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
          retry_after: null,
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
          retry_after: "60",
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
          retry_after: "120",
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
          retry_after: null,
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

/**
 * GH-38 nil-stripping: required × nullable matrix on WebhookDestination.
 *
 *   ┌──────────┬──────────────────────────┬──────────────────────────┐
 *   │          │ nullable: false           │ nullable: true           │
 *   ├──────────┼──────────────────────────┼──────────────────────────┤
 *   │ required │ url, method              │ retry_after              │
 *   ├──────────┼──────────────────────────┼──────────────────────────┤
 *   │ optional │ timeout_ms               │ description              │
 *   └──────────┴──────────────────────────┴──────────────────────────┘
 *
 * Also: scope on ClientCredentialsGrant is optional non-nullable.
 */

describe("GH-38 — optional non-nullable absent from response when not sent", () => {
  test("POST without timeout_ms and scope omits both keys from response JSON", async () => {
    const { data, error, response } = await subscriptionCreate({
      body: {
        name: "Minimal webhook",
        destination: {
          destination_type: "webhook",
          url: "https://hooks.example.com/minimal",
          method: "POST",
          retry_after: "30",
          auth: {
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-minimal",
            grant: {
              grant_type: "client_credentials",
              client_secret: "sk-minimal-secret",
            },
          },
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);

    const raw = data as Record<string, unknown>;
    const dest = raw.destination as Record<string, unknown>;

    // optional non-nullable not sent → key absent
    expect(dest).not.toHaveProperty("timeout_ms");

    // nested optional non-nullable (scope) not sent → key absent
    const auth = dest.auth as Record<string, unknown>;
    const grant = auth.grant as Record<string, unknown>;
    expect(grant).not.toHaveProperty("scope");

    // required fields still present
    expect(dest.url).toBe("https://hooks.example.com/minimal");
    expect(dest.retry_after).toBe("30");
  });
});

describe("GH-38 — all fields filled emits every key", () => {
  test("POST with timeout_ms, description, and scope returns all keys in response", async () => {
    const { data, error, response } = await subscriptionCreate({
      body: {
        name: "Full webhook",
        destination: {
          destination_type: "webhook",
          url: "https://hooks.example.com/full",
          method: "POST",
          retry_after: null,
          timeout_ms: 5000,
          description: "Primary order hook",
          auth: {
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-full",
            grant: {
              grant_type: "client_credentials",
              client_secret: "sk-full-secret",
              scope: "read:events write:webhooks",
            },
          },
        },
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);

    const raw = data as Record<string, unknown>;
    const dest = raw.destination as Record<string, unknown>;

    // required non-nullable — always present
    expect(dest.url).toBe("https://hooks.example.com/full");
    expect(dest.method).toBe("POST");

    // required nullable with null — key present, value null
    expect(dest).toHaveProperty("retry_after");
    expect(dest.retry_after).toBeNull();

    // optional non-nullable with value — key present
    expect(dest.timeout_ms).toBe(5000);

    // optional nullable with value — key present
    expect(dest.description).toBe("Primary order hook");

    // nested optional non-nullable with value
    const auth = dest.auth as Record<string, unknown>;
    const grant = auth.grant as Record<string, unknown>;
    expect(grant.scope).toBe("read:events write:webhooks");
  });
});

describe("GH-38 — required nullable field with null vs non-null", () => {
  test("retry_after: null emits key with null, retry_after: '120' emits value", async () => {
    // With null
    const { data: d1 } = await subscriptionCreate({
      body: {
        name: "Null retry",
        destination: {
          destination_type: "webhook",
          url: "https://hooks.example.com/null-retry",
          method: "POST",
          retry_after: null,
          auth: {
            auth_type: "basic",
            username: "alice",
            password: "s3cret",
          },
        },
      },
    });

    const dest1 = (d1 as Record<string, unknown>).destination as Record<
      string,
      unknown
    >;
    expect(dest1).toHaveProperty("retry_after");
    expect(dest1.retry_after).toBeNull();

    // With value
    const { data: d2 } = await subscriptionCreate({
      body: {
        name: "Valued retry",
        destination: {
          destination_type: "webhook",
          url: "https://hooks.example.com/valued-retry",
          method: "POST",
          retry_after: "120",
          auth: {
            auth_type: "basic",
            username: "bob",
            password: "pa$$word",
          },
        },
      },
    });

    const dest2 = (d2 as Record<string, unknown>).destination as Record<
      string,
      unknown
    >;
    expect(dest2.retry_after).toBe("120");
  });
});

/**
 * GH-41 — Jason.Encoder renders Response struct directly (no Mapper.to_map).
 *
 * The /subscriptions-struct endpoint returns a hardcoded SubscriptionResponse
 * struct. Jason.Encoder handles nil-stripping and encoding automatically.
 */

describe("GH-41 — GET /api/subscriptions-struct returns correct JSON via Jason.Encoder", () => {
  test("Response struct rendered with discriminators and nil-stripping", async () => {
    const { data, error, response } = await subscriptionShowStruct();

    expect(error).toBeUndefined();
    expect(response.status).toBe(200);
    expect(data).toBeDefined();

    expect(data!.id).toBe("b7f4c2a0-1e3d-4a7e-9c6b-8f2d1e5c3a9b");
    expect(data!.name).toBe("GH-41 struct endpoint");
    expect(data!.destination.destination_type).toBe("webhook");

    if (data!.destination.destination_type === "webhook") {
      expect(data!.destination.url).toBe("https://hooks.example.com/gh41");
      expect(data!.destination.method).toBe("POST");

      // required nullable nil — present
      expect(data!.destination.retry_after).toBeNull();

      // optional non-nullable nil — absent
      const destRaw = data!.destination as Record<string, unknown>;
      expect(destRaw).not.toHaveProperty("timeout_ms");

      // optional nullable nil — present
      expect(destRaw).toHaveProperty("description");
      expect(destRaw.description).toBeNull();

      expect(data!.destination.auth.auth_type).toBe("oauth");

      if (data!.destination.auth.auth_type === "oauth") {
        expect(data!.destination.auth.token_url).toBe(
          "https://auth.example.com/oauth/token",
        );
        expect(data!.destination.auth.client_id).toBe("client-gh41");
        expect(data!.destination.auth.grant.grant_type).toBe(
          "client_credentials",
        );

        if (
          data!.destination.auth.grant.grant_type === "client_credentials"
        ) {
          expect(data!.destination.auth.grant.scope).toBe("read:events");
        }
      }
    }
  });
});

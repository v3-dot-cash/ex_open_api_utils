import { client } from "@hey-api/client-fetch";
import { describe, expect, test } from "vitest";

/**
 * GH-30 HTTP regression lock.
 *
 * Exercises the full Phoenix + Ecto + OpenApiSpex + ex_open_api_utils
 * pipeline against a real HTTP surface. Each test POSTs a notification
 * with a polymorphic channel, then asserts the response body carries the
 * discriminator field on the channel sub-object — the exact key that
 * GH-30's pre-fix behaviour silently dropped because the variant
 * submodule's defstruct didn't include it.
 *
 * The tests also round-trip via GET and PUT to catch any direction that
 * might be missed by a POST-only check.
 */

const NOTIFICATIONS = "/api/notifications";

async function createNotification<T>(body: unknown) {
  return client.post<T>({
    url: NOTIFICATIONS,
    body,
  });
}

describe("POST /api/notifications — polymorphic channel round-trip (GH-30)", () => {
  test("email channel survives cast_to_schema with channel_type preserved", async () => {
    const { data, error, response } = await createNotification<{
      id: string;
      subject: string;
      channel: {
        channel_type: string;
        to: string;
        from: string;
        body: string;
      };
    }>({
      subject: "Your order has shipped",
      channel: {
        channel_type: "email",
        to: "buyer@example.com",
        from: "store@example.com",
        body: "Tracking: 1Z999AA10123456784",
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);
    expect(data).toBeDefined();

    expect(data!.channel.channel_type).toBe("email");
    expect(data!.channel.to).toBe("buyer@example.com");
    expect(data!.channel.from).toBe("store@example.com");
    expect(data!.channel.body).toBe("Tracking: 1Z999AA10123456784");
  });

  test("sms channel survives cast_to_schema with channel_type preserved", async () => {
    const { data, error, response } = await createNotification<{
      id: string;
      subject: string;
      channel: {
        channel_type: string;
        phone_number: string;
        body: string;
      };
    }>({
      subject: "Verification code",
      channel: {
        channel_type: "sms",
        phone_number: "+15551234567",
        body: "Your code is 4242",
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);
    expect(data!.channel.channel_type).toBe("sms");
    expect(data!.channel.phone_number).toBe("+15551234567");
    expect(data!.channel.body).toBe("Your code is 4242");
  });

  test("webhook channel survives cast_to_schema with channel_type preserved", async () => {
    const { data, error, response } = await createNotification<{
      id: string;
      subject: string;
      channel: {
        channel_type: string;
        url: string;
        method: string;
      };
    }>({
      subject: "Order event",
      channel: {
        channel_type: "webhook",
        url: "https://hooks.example.com/abc",
        method: "POST",
      },
    });

    expect(error).toBeUndefined();
    expect(response.status).toBe(201);
    expect(data!.channel.channel_type).toBe("webhook");
    expect(data!.channel.url).toBe("https://hooks.example.com/abc");
    expect(data!.channel.method).toBe("POST");
  });
});

describe("GET /api/notifications/:id — round-trip preserves discriminator", () => {
  test("show returns the same channel_type the create body sent", async () => {
    const { data: created } = await createNotification<{
      id: string;
      channel: { channel_type: string };
    }>({
      subject: "Round-trip test",
      channel: {
        channel_type: "email",
        to: "a@b.test",
        from: "c@d.test",
        body: "round-trip",
      },
    });

    expect(created).toBeDefined();
    const id = created!.id;

    const { data: fetched, error, response } = await client.get<{
      id: string;
      subject: string;
      channel: {
        channel_type: string;
        to: string;
        from: string;
        body: string;
      };
    }>({ url: `${NOTIFICATIONS}/${id}` });

    expect(error).toBeUndefined();
    expect(response.status).toBe(200);
    expect(fetched!.id).toBe(id);
    expect(fetched!.channel.channel_type).toBe("email");
    expect(fetched!.channel.to).toBe("a@b.test");
  });
});

describe("PUT /api/notifications/:id — switching variant across the wire", () => {
  test("email → webhook channel swap preserves the new discriminator", async () => {
    const { data: created } = await createNotification<{ id: string }>({
      subject: "Swap me",
      channel: {
        channel_type: "email",
        to: "a@b.test",
        from: "c@d.test",
        body: "initial",
      },
    });

    const id = created!.id;

    const { data: updated, error, response } = await client.put<{
      channel: {
        channel_type: string;
        url: string;
        method: string;
      };
    }>({
      url: `${NOTIFICATIONS}/${id}`,
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
    expect(updated!.channel.channel_type).toBe("webhook");
    expect(updated!.channel.url).toBe("https://hooks.example.com/after");
    expect(updated!.channel.method).toBe("POST");
  });
});

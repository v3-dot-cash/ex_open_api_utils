/**
 * Sample: creating a notification with an email channel.
 *
 * Uses the typed TypeScript SDK that `mix openapi.dump` + hey-api emits
 * into `integration-tests/generated/`. The GH-30 parent-contextual
 * variant siblings mean hey-api sees a concrete `allOf` composition for
 * each variant and can emit a union that carries `channel_type` as a
 * real discriminant property on each arm — so TypeScript's narrowing
 * works out of the box.
 *
 * Run the local tier end-to-end first to materialize the generated SDK:
 *
 *     make vitest-generate-sdk
 *
 * Then import from `@/generated/...` (path alias configured in
 * integration-tests/tsconfig.json) to see the full typed surface.
 */
import { client } from "@hey-api/client-fetch";

export async function createEmailNotification(params: {
  subject: string;
  to: string;
  from: string;
  body: string;
}) {
  return client.post({
    url: "/api/notifications",
    body: {
      subject: params.subject,
      channel: {
        channel_type: "email",
        to: params.to,
        from: params.from,
        body: params.body,
      },
    },
  });
}

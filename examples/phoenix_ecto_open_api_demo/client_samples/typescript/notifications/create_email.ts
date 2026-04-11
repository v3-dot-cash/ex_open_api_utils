/**
 * Sample: creating a notification with an email channel.
 *
 * Uses the typed SDK that @hey-api/openapi-ts emits under the
 * production-style plugin stack (@hey-api/client-ky, @hey-api/typescript,
 * @hey-api/sdk, @hey-api/schemas, zod). The GH-30 parent-contextual
 * variant siblings mean hey-api sees a concrete allOf composition for
 * each variant and can emit a discriminated union with channel_type as
 * a real discriminant property — so TypeScript narrowing works out of
 * the box.
 *
 * The generated SDK lives under integration-tests/generated/ after
 * `make vitest-dump-spec` writes priv/static/openapi.json and the
 * @hey-api/vite-plugin runs on vitest startup.
 */
import { notificationCreate } from "../../../integration-tests/generated/sdk.gen";

export async function createEmailNotification(params: {
  subject: string;
  to: string;
  from: string;
  body: string;
}) {
  return notificationCreate({
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

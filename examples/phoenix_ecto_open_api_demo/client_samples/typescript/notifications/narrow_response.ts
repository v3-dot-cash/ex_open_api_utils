/**
 * Sample: narrowing a notification response by its discriminant.
 *
 * The GH-30 parent-contextual variant siblings expose `channel_type` as a
 * real defstruct field on every variant, so the OpenAPI spec carries a
 * `discriminator.propertyName: "channel_type"` + `oneOf` on the parent's
 * `:channel` property. hey-api picks this up and emits the channel as a
 * discriminated union where each arm carries its own channel_type literal
 * as a real property — which gives TypeScript everything it needs to
 * narrow a union member to its full shape via a plain switch on the
 * discriminant, no runtime casts required.
 *
 * Import the generated types directly from the typescript plugin output.
 * The exact type name is hey-api-version-dependent; NotificationResponse
 * is the one v0.95 emits for the parent response shape.
 */
import type { NotificationResponse } from "../../../integration-tests/generated/types.gen";

export function describeChannel(notification: NotificationResponse): string {
  const channel = notification.channel;

  switch (channel.channel_type) {
    case "email":
      // TypeScript narrows `channel` to the email arm: to, from, body
      // are all reachable without further checks.
      return `email to ${channel.to} from ${channel.from}`;
    case "sms":
      return `sms to ${channel.phone_number}`;
    case "webhook":
      return `webhook ${channel.method} ${channel.url}`;
  }
}

/**
 * Sample: narrowing a notification response by discriminant.
 *
 * The GH-30 parent-contextual variant siblings expose `channel_type` as a
 * real defstruct field on every variant, so the OpenAPI spec carries a
 * `discriminator.propertyName: "channel_type"` + `oneOf` on the parent's
 * `:channel` property. Generated TypeScript SDKs pick this up as a
 * discriminated union, which lets consumers narrow via `switch` on the
 * discriminant without any runtime casts.
 *
 * This example shows the pattern consumers would write after importing
 * the generated union type from `@/generated/...`. The union type's
 * exact name is hey-api version-dependent — substitute your own.
 */
type NotificationChannel =
  | { channel_type: "email"; to: string; from: string; body: string }
  | { channel_type: "sms"; phone_number: string; body: string }
  | { channel_type: "webhook"; url: string; method: string };

export function describeChannel(channel: NotificationChannel): string {
  switch (channel.channel_type) {
    case "email":
      // TypeScript narrows to the email arm: `to`, `from`, `body` are reachable.
      return `email to ${channel.to} from ${channel.from}`;
    case "sms":
      return `sms to ${channel.phone_number}`;
    case "webhook":
      return `webhook ${channel.method} ${channel.url}`;
  }
}

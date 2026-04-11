/**
 * Sample: creating a notification with a webhook channel.
 */
import { notificationCreate } from "../../../integration-tests/generated/sdk.gen";

export async function createWebhookNotification(params: {
  subject: string;
  url: string;
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
}) {
  return notificationCreate({
    body: {
      subject: params.subject,
      channel: {
        channel_type: "webhook",
        url: params.url,
        method: params.method,
      },
    },
  });
}

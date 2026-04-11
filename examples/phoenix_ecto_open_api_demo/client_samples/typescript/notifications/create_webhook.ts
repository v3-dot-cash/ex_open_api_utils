/**
 * Sample: creating a notification with a webhook channel.
 */
import { client } from "@hey-api/client-fetch";

export async function createWebhookNotification(params: {
  subject: string;
  url: string;
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
}) {
  return client.post({
    url: "/api/notifications",
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

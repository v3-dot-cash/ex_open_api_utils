/**
 * Sample: creating a notification with an sms channel.
 */
import { client } from "@hey-api/client-fetch";

export async function createSmsNotification(params: {
  subject: string;
  phone_number: string;
  body: string;
}) {
  return client.post({
    url: "/api/notifications",
    body: {
      subject: params.subject,
      channel: {
        channel_type: "sms",
        phone_number: params.phone_number,
        body: params.body,
      },
    },
  });
}

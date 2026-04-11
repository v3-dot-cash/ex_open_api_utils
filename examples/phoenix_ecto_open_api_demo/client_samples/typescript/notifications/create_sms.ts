/**
 * Sample: creating a notification with an sms channel.
 */
import { notificationCreate } from "../../../integration-tests/generated/sdk.gen";

export async function createSmsNotification(params: {
  subject: string;
  phone_number: string;
  body: string;
}) {
  return notificationCreate({
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

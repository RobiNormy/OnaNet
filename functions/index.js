const crypto = require("node:crypto");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

initializeApp();

const relaySecret = defineSecret("ONANET_PUSH_RELAY_SECRET");

function secretsMatch(supplied, expected) {
  const suppliedBuffer = Buffer.from(supplied || "", "utf8");
  const expectedBuffer = Buffer.from(expected || "", "utf8");
  return suppliedBuffer.length === expectedBuffer.length
    && suppliedBuffer.length > 0
    && crypto.timingSafeEqual(suppliedBuffer, expectedBuffer);
}

exports.sendProviderPush = onRequest(
  {
    region: "europe-west1",
    secrets: [relaySecret],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).json({ error: "Method not allowed" });
      return;
    }

    if (!secretsMatch(
      request.get("X-OnaNet-Push-Secret"),
      relaySecret.value(),
    )) {
      response.status(401).json({ error: "Unauthorised" });
      return;
    }

    const { tokens, title, body, data = {} } = request.body || {};
    if (!Array.isArray(tokens) || tokens.length === 0 || tokens.length > 500) {
      response.status(400).json({ error: "Provide between 1 and 500 tokens" });
      return;
    }
    if (typeof title !== "string" || typeof body !== "string") {
      response.status(400).json({ error: "Title and body are required" });
      return;
    }

    const messageData = Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)]),
    );
    const result = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: messageData,
      android: {
        priority: "high",
        notification: { channelId: "onanet_updates" },
      },
    });

    const invalidTokens = [];
    result.responses.forEach((item, index) => {
      if (!item.success && [
        "messaging/invalid-registration-token",
        "messaging/registration-token-not-registered",
      ].includes(item.error?.code)) {
        invalidTokens.push(tokens[index]);
      }
    });
    response.status(200).json({
      sent: result.successCount,
      failed: result.failureCount,
      invalid_tokens: invalidTokens,
    });
  },
);

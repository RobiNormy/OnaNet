from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
import unittest

import resend

from backend.api.resend_webhooks import (
    _attachment_metadata,
    _received_at,
    _plain_address,
    _string_list,
    _trim_body,
)


class ResendWebhookTests(unittest.TestCase):
    def test_sdk_verifies_signed_received_event(self) -> None:
        secret_bytes = b"onanet-webhook-test-secret"
        secret = "whsec_" + base64.b64encode(secret_bytes).decode()
        payload = json.dumps(
            {
                "type": "email.received",
                "data": {"email_id": "received-email-id"},
            },
            separators=(",", ":"),
        )
        event_id = "msg_test"
        timestamp = str(int(time.time()))
        signature = base64.b64encode(
            hmac.new(
                secret_bytes,
                f"{event_id}.{timestamp}.{payload}".encode(),
                hashlib.sha256,
            ).digest()
        ).decode()

        event = resend.Webhooks.verify(
            {
                "payload": payload,
                "headers": {
                    "id": event_id,
                    "timestamp": timestamp,
                    "signature": f"v1,{signature}",
                },
                "webhook_secret": secret,
            }
        )

        self.assertEqual(event["type"], "email.received")
        self.assertEqual(event["data"]["email_id"], "received-email-id")

    def test_sdk_rejects_bad_signature(self) -> None:
        with self.assertRaises(ValueError):
            resend.Webhooks.verify(
                {
                    "payload": '{"type":"email.received"}',
                    "headers": {
                        "id": "msg_test",
                        "timestamp": str(int(time.time())),
                        "signature": "v1,not-valid",
                    },
                    "webhook_secret": "whsec_dGVzdA==",
                }
            )

    def test_received_email_values_are_bounded_and_normalized(self) -> None:
        self.assertEqual(_string_list([" a@example.com ", ""]), ["a@example.com"])
        self.assertEqual(len(_trim_body("x" * 300_000) or ""), 250_000)
        self.assertIsNotNone(_received_at("2026-08-14T10:00:00Z").tzinfo)
        self.assertEqual(
            _attachment_metadata(
                [{"id": "a", "filename": "proof.pdf", "size": 42}]
            ),
            [{"id": "a", "filename": "proof.pdf"}],
        )
        self.assertEqual(
            _plain_address("OnaNet Support <Support@Mail.OnaNet.App>"),
            "support@mail.onanet.app",
        )


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import unittest

from backend.services.email_service import (
    EmailConfigurationError,
    EmailService,
)


class EmailServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_send_builds_resend_payload(self) -> None:
        calls = []

        def sender(payload, options):
            calls.append((payload, options))
            return {"id": "email_123"}

        service = EmailService(
            api_key="re_test",
            from_email="OnaNet <hello@example.com>",
            sender=sender,
        )

        result = await service.send(
            to="provider@example.com",
            subject=" Welcome ",
            html="<strong>Welcome</strong>",
            tags={"category": "welcome"},
            idempotency_key="welcome-provider-1",
        )

        self.assertEqual(result.id, "email_123")
        self.assertEqual(calls[0][0]["to"], ["provider@example.com"])
        self.assertEqual(calls[0][0]["subject"], "Welcome")
        self.assertEqual(calls[0][0]["from"], "OnaNet <hello@example.com>")
        self.assertNotIn("reply_to", calls[0][0])
        self.assertEqual(
            calls[0][1], {"idempotency_key": "welcome-provider-1"}
        )

    async def test_send_can_override_default_sender(self) -> None:
        calls = []

        def sender(payload, options):
            calls.append((payload, options))
            return {"id": "email_security"}

        service = EmailService(
            api_key="re_test",
            from_email="OnaNet <hello@mail.onanet.app>",
            sender=sender,
        )

        await service.send(
            to="customer@example.com",
            from_email="OnaNet Security <no-reply@mail.onanet.app>",
            subject="Reset your password",
            text="Reset instructions",
        )

        self.assertEqual(
            calls[0][0]["from"],
            "OnaNet Security <no-reply@mail.onanet.app>",
        )
        self.assertNotIn("reply_to", calls[0][0])

    async def test_support_sender_invites_replies(self) -> None:
        calls = []

        def sender(payload, options):
            calls.append((payload, options))
            return {"id": "email_support"}

        service = EmailService(
            api_key="re_test",
            from_email="OnaNet <hello@mail.onanet.app>",
            reply_to="support@mail.onanet.app",
            sender=sender,
        )
        await service.send(
            to="customer@example.com",
            from_email="OnaNet Support <support@mail.onanet.app>",
            subject="Support update",
            text="We received your request.",
        )

        self.assertEqual(
            calls[0][0]["reply_to"],
            "support@mail.onanet.app",
        )

    async def test_missing_api_key_is_reported(self) -> None:
        service = EmailService(
            api_key=" ",
            from_email="hello@example.com",
            sender=lambda *_: {"id": "unused"},
        )

        with self.assertRaises(EmailConfigurationError):
            await service.send(to="provider@example.com", subject="Hi", text="Hi")

    async def test_content_is_required(self) -> None:
        service = EmailService(
            api_key="re_test",
            from_email="hello@example.com",
            sender=lambda *_: {"id": "unused"},
        )

        with self.assertRaises(ValueError):
            await service.send(to="provider@example.com", subject="Hi")


if __name__ == "__main__":
    unittest.main()

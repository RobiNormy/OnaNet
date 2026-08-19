import unittest

from backend.services.notification_dispatcher import channels_for_limits


class NotificationDispatcherTests(unittest.TestCase):
    def test_in_app_only_plan_creates_no_external_jobs(self) -> None:
        limits = {
            "in_app_alerts": True,
            "push_request_alerts": False,
            "external_alerts": False,
        }
        self.assertEqual(channels_for_limits(limits, sms_enabled=False), ())

    def test_pro_routes_push_and_email_without_sms_top_up(self) -> None:
        limits = {
            "push_request_alerts": True,
            "external_alerts": True,
        }
        self.assertEqual(
            channels_for_limits(limits, sms_enabled=False),
            ("push", "email"),
        )

    def test_sms_is_added_only_when_explicitly_enabled(self) -> None:
        limits = {
            "push_request_alerts": True,
            "external_alerts": True,
        }
        self.assertEqual(
            channels_for_limits(limits, sms_enabled=True),
            ("push", "email", "sms"),
        )


if __name__ == "__main__":
    unittest.main()

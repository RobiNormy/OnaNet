import unittest

from backend.services.subscription_services import TIER_LIMITS


class SubscriptionTierTests(unittest.TestCase):
    def test_growth_is_capped_and_in_app_only(self) -> None:
        growth = TIER_LIMITS["growth"]

        self.assertEqual(growth["max_packages"], 5)
        self.assertEqual(growth["max_coverage_areas"], 5)
        self.assertEqual(growth["max_staff_accounts"], 3)
        self.assertEqual(growth["featured_in_search"], "mid")
        self.assertTrue(growth["in_app_alerts"])
        self.assertFalse(growth["push_request_alerts"])
        self.assertFalse(growth["external_alerts"])

    def test_pro_has_lead_protection_features(self) -> None:
        pro = TIER_LIMITS["pro"]

        self.assertEqual(pro["featured_in_search"], "pinned")
        self.assertTrue(pro["push_request_alerts"])
        self.assertTrue(pro["external_alerts"])
        self.assertTrue(pro["priority_inbox"])
        self.assertTrue(pro["auto_request_reminders"])
        self.assertTrue(pro["demand_intelligence_enabled"])

    def test_free_does_not_exceed_growth_capacity(self) -> None:
        free = TIER_LIMITS["free"]
        growth = TIER_LIMITS["growth"]

        self.assertLess(free["max_packages"], growth["max_packages"])
        self.assertLess(free["max_coverage_areas"], growth["max_coverage_areas"])
        self.assertLess(free["max_staff_accounts"], growth["max_staff_accounts"])


if __name__ == "__main__":
    unittest.main()

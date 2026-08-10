from __future__ import annotations

import unittest

from backend.services.geoapify_service import (
    GeoapifyConfigurationError,
    GeoapifyLocation,
    GeoapifyService,
)


class GeoapifyServiceTests(unittest.TestCase):
    def test_feature_is_normalized_for_flutter(self) -> None:
        location = GeoapifyService._location_from_feature(
            {
                "properties": {
                    "name": "Kutus",
                    "formatted": "Kutus, Kirinyaga County, Kenya",
                    "lat": -0.5751,
                    "lon": 37.3269,
                }
            }
        )

        self.assertIsNotNone(location)
        assert location is not None
        self.assertEqual(location.title, "Kutus")
        self.assertIn("Kirinyaga", location.subtitle)
        self.assertEqual(location.latitude, -0.5751)

    def test_feature_without_coordinates_is_ignored(self) -> None:
        location = GeoapifyService._location_from_feature(
            {"properties": {"name": "Kutus"}}
        )
        self.assertIsNone(location)

    def test_missing_api_key_is_reported(self) -> None:
        service = GeoapifyService(api_key=" ")
        with self.assertRaises(GeoapifyConfigurationError):
            service._require_api_key()

    def test_shorter_prefix_match_is_ranked_first(self) -> None:
        kutus = GeoapifyLocation("Kutus", "Kirinyaga, Kenya", -0.57, 37.32)
        kutulo = GeoapifyLocation("Kutulo", "Wajir, Kenya", 2.15, 40.05)
        ranked = sorted(
            [kutulo, kutus],
            key=lambda item: GeoapifyService._relevance_score("kutu", item),
        )
        self.assertEqual(ranked[0].title, "Kutus")

    def test_unrelated_helipad_is_rejected(self) -> None:
        helipad = GeoapifyLocation(
            "Ngaideithia Helipad",
            "Tharaka Nithi County, Kenya",
            -0.3,
            37.9,
        )
        self.assertFalse(GeoapifyService._is_relevant("Kutus", helipad))


if __name__ == "__main__":
    unittest.main()

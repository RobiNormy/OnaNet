from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import httpx

from backend.core.config import settings


class GeoapifyConfigurationError(RuntimeError):
    pass


class GeoapifyRequestError(RuntimeError):
    pass


@dataclass(frozen=True)
class GeoapifyLocation:
    title: str
    subtitle: str
    latitude: float
    longitude: float

    def to_dict(self) -> dict[str, str | float]:
        return {
            "title": self.title,
            "subtitle": self.subtitle,
            "latitude": self.latitude,
            "longitude": self.longitude,
        }


class GeoapifyService:
    _AUTOCOMPLETE_URL = "https://api.geoapify.com/v1/geocode/autocomplete"
    _SEARCH_URL = "https://api.geoapify.com/v1/geocode/search"
    _REVERSE_URL = "https://api.geoapify.com/v1/geocode/reverse"

    def __init__(self, api_key: str | None = None) -> None:
        self._api_key = api_key if api_key is not None else settings.GEOAPIFY_API_KEY

    def _require_api_key(self) -> str:
        key = (self._api_key or "").strip()
        if not key:
            raise GeoapifyConfigurationError("Geoapify is not configured.")
        return key

    async def autocomplete(self, text: str, limit: int = 6) -> list[GeoapifyLocation]:
        query = text.strip()
        payload = await self._get(
            self._AUTOCOMPLETE_URL,
            {
                "text": query,
                "filter": "countrycode:ke",
                "bias": "countrycode:ke",
                "type": "city",
                "format": "geojson",
                "limit": str(limit),
            },
        )
        locations = self._locations_from_payload(payload)
        locations = [item for item in locations if self._is_relevant(query, item)]
        if not locations:
            payload = await self._get(
                self._AUTOCOMPLETE_URL,
                {
                    "text": query,
                    "filter": "countrycode:ke",
                    "bias": "countrycode:ke",
                    "format": "geojson",
                    "limit": str(limit),
                },
            )
            locations = self._locations_from_payload(payload)
            locations = [item for item in locations if self._is_relevant(query, item)]
        if not locations:
            payload = await self._get(
                self._SEARCH_URL,
                {
                    "text": query,
                    "filter": "countrycode:ke",
                    "format": "geojson",
                    "limit": str(limit),
                },
            )
            locations = self._locations_from_payload(payload)
            locations = [item for item in locations if self._is_relevant(query, item)]

        locations.sort(key=lambda item: self._relevance_score(query, item))
        return locations[:limit]

    def _locations_from_payload(self, payload: dict[str, Any]) -> list[GeoapifyLocation]:
        locations: list[GeoapifyLocation] = []
        seen: set[tuple[str, float, float]] = set()
        for feature in payload.get("features", []):
            location = self._location_from_feature(feature)
            if location is None:
                continue
            key = (location.title.casefold(), location.latitude, location.longitude)
            if key in seen:
                continue
            seen.add(key)
            locations.append(location)
        return locations

    @staticmethod
    def _is_relevant(query: str, location: GeoapifyLocation) -> bool:
        words = GeoapifyService._normalize(query).split()
        candidate = GeoapifyService._normalize(
            f"{location.title} {location.subtitle}"
        )
        return bool(words) and all(word in candidate for word in words)

    @staticmethod
    def _relevance_score(query: str, location: GeoapifyLocation) -> tuple[int, int]:
        normalized_query = GeoapifyService._normalize(query)
        normalized_title = GeoapifyService._normalize(location.title)
        if normalized_title == normalized_query:
            rank = 0
        elif normalized_title.startswith(normalized_query):
            rank = 1
        elif normalized_query in normalized_title:
            rank = 2
        else:
            rank = 3
        return rank, abs(len(normalized_title) - len(normalized_query))

    @staticmethod
    def _normalize(value: str) -> str:
        return " ".join(value.casefold().replace("/", " ").split())

    async def reverse(self, latitude: float, longitude: float) -> GeoapifyLocation | None:
        payload = await self._get(
            self._REVERSE_URL,
            {
                "lat": str(latitude),
                "lon": str(longitude),
                "format": "geojson",
                "limit": "1",
            },
        )
        for feature in payload.get("features", []):
            location = self._location_from_feature(feature)
            if location is not None:
                return location
        return None

    async def _get(self, url: str, params: dict[str, str]) -> dict[str, Any]:
        params["apiKey"] = self._require_api_key()
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                payload = response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise GeoapifyRequestError("Location provider request failed.") from error
        if not isinstance(payload, dict):
            raise GeoapifyRequestError("Location provider returned invalid data.")
        return payload

    @staticmethod
    def _location_from_feature(feature: Any) -> GeoapifyLocation | None:
        if not isinstance(feature, dict):
            return None
        properties = feature.get("properties")
        if not isinstance(properties, dict):
            return None
        latitude = properties.get("lat")
        longitude = properties.get("lon")
        if not isinstance(latitude, (int, float)) or not isinstance(
            longitude, (int, float)
        ):
            return None

        title = GeoapifyService._first_text(
            properties,
            "name",
            "address_line1",
            "street",
            "suburb",
            "district",
            "city",
            "county",
        )
        if title is None:
            return None
        formatted = GeoapifyService._first_text(
            properties, "formatted", "address_line2"
        )
        subtitle = formatted or "Kenya"
        if subtitle.casefold() == title.casefold():
            subtitle = "Kenya"
        return GeoapifyLocation(
            title=title,
            subtitle=subtitle,
            latitude=float(latitude),
            longitude=float(longitude),
        )

    @staticmethod
    def _first_text(properties: dict[str, Any], *keys: str) -> str | None:
        for key in keys:
            value = properties.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
        return None


geoapify_service = GeoapifyService()

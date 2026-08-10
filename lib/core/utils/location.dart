// Shared location permission, distance, and geocoding helpers.
import 'package:geolocator/geolocator.dart';
import 'package:ona_net/core/network/api_client.dart';

class LocationSuggestion {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  const LocationSuggestion({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  String get displayName => subtitle.isEmpty ? title : '$title, $subtitle';
}

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.area,
  });

  final double latitude;
  final double longitude;
  final String? area;
}

class Location {
  static Future<String?> findNearbyLandmark(
    double latitude,
    double longitude,
  ) async {
    final place = await _reverseLocation(latitude, longitude);
    return place == null ? null : 'Near ${place.title}';
  }

  static Future<String?> getCurrentArea() async {
    final location = await getCurrentLocation();
    return location?.area;
  }

  static Future<UserLocation?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100,
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      final place = await _reverseLocation(
        position.latitude,
        position.longitude,
      );

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        area: place?.title,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<LocationSuggestion>> searchAreas(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];

    try {
      final response = await sharedApiClient.get<dynamic>(
        '$onaNetApiBaseUrl/locations/autocomplete',
        queryParameters: {'text': trimmedQuery, 'limit': 6},
      );
      final body = response.data;
      if (body is! Map) return [];
      final results = body['results'];
      if (results is! List) return [];
      return results
          .whereType<Map>()
          .map((item) => _suggestionFromMap(item))
          .whereType<LocationSuggestion>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<LocationSuggestion?> _reverseLocation(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await sharedApiClient.get<dynamic>(
        '$onaNetApiBaseUrl/locations/reverse',
        queryParameters: {'latitude': latitude, 'longitude': longitude},
      );
      final body = response.data;
      if (body is! Map || body['result'] is! Map) return null;
      return _suggestionFromMap(body['result'] as Map);
    } catch (_) {
      return null;
    }
  }

  static LocationSuggestion? _suggestionFromMap(Map item) {
    final title = item['title']?.toString().trim() ?? '';
    final subtitle = item['subtitle']?.toString().trim() ?? '';
    final latitude = item['latitude'];
    final longitude = item['longitude'];
    if (title.isEmpty || latitude is! num || longitude is! num) return null;
    return LocationSuggestion(
      title: title,
      subtitle: subtitle,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }
}

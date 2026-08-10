// Shared location permission, distance, and geocoding helpers.
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

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
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final landmark = _firstUsefulLandmark([
        place.name,
        place.street,
        place.thoroughfare,
        place.subLocality,
        place.locality,
      ]);
      return landmark == null ? null : 'Near $landmark';
    } catch (_) {
      return null;
    }
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
      final placemark = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemark.isEmpty) return null;
      final place = placemark.first;
      final subLocality = place.subLocality;
      final locality = place.locality;
      final area = subLocality != null && subLocality.isNotEmpty
          ? subLocality
          : locality;

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        area: area,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<LocationSuggestion>> searchAreas(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];

    try {
      final searchQuery = _withKenyaBias(trimmedQuery);
      final locations = await geocoding.locationFromAddress(searchQuery);
      final suggestions = <LocationSuggestion>[];
      final seen = <String>{};

      for (final location in locations.take(5)) {
        final placemarks = await geocoding.placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (placemarks.isEmpty) continue;

        final place = placemarks.first;
        final placeParts = [
          place.subLocality,
          place.locality,
          place.name,
          place.street,
          place.thoroughfare,
          place.subAdministrativeArea,
          place.administrativeArea,
        ];
        final title = _matchingSearchPart(trimmedQuery, placeParts);
        if (title == null) continue;
        final subtitle = _joinUnique([
          place.name,
          place.street,
          place.thoroughfare,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country,
        ], skip: title);

        final key = '$title|$subtitle'.toLowerCase();
        if (!seen.add(key)) continue;

        suggestions.add(
          LocationSuggestion(
            title: title,
            subtitle: subtitle,
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
      }

      return suggestions;
    } catch (_) {
      return [];
    }
  }

  static String? _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String? _firstUsefulLandmark(List<String?> values) {
    final coordinate = RegExp(r'^[-+]?\d+(\.\d+)?\s*,\s*[-+]?\d+(\.\d+)?$');
    for (final value in values) {
      final candidate = value?.trim();
      if (candidate == null || candidate.isEmpty) continue;
      if (coordinate.hasMatch(candidate)) continue;
      if (candidate.toLowerCase() == 'unnamed road') continue;
      return candidate;
    }
    return null;
  }

  static String? _matchingSearchPart(String query, List<String?> placeParts) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.length < 3) return null;

    final queryWords = normalizedQuery
        .split(' ')
        .where((word) => word.length >= 3)
        .toList();
    if (queryWords.isEmpty) return null;

    for (final value in placeParts) {
      final candidate = value?.trim();
      if (candidate == null || candidate.isEmpty) continue;
      final normalizedCandidate = _normalizeSearchText(candidate);
      final candidateWords = normalizedCandidate.split(' ');
      final matches = queryWords.every(
        (queryWord) => candidateWords.any(
          (candidateWord) =>
              candidateWord == queryWord ||
              (queryWord.length >= 4 && candidateWord.startsWith(queryWord)),
        ),
      );
      if (matches) return candidate;
    }
    return null;
  }

  static String _normalizeSearchText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static String _withKenyaBias(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('kenya') || lowerQuery.contains('ke')) {
      return query;
    }
    return '$query, Kenya';
  }

  static String _joinUnique(List<String?> values, {String? skip}) {
    final parts = <String>[];
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) continue;
      if (skip != null && trimmed.toLowerCase() == skip.toLowerCase()) continue;
      if (parts.any((part) => part.toLowerCase() == trimmed.toLowerCase())) {
        continue;
      }
      parts.add(trimmed);
    }
    return parts.join(', ');
  }
}

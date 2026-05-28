import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class LocationSuggestion {
  final String title;
  final String subtitle;

  const LocationSuggestion({required this.title, required this.subtitle});

  String get displayName => subtitle.isEmpty ? title : '$title, $subtitle';
}

class Location {
  static Future<String?> getCurrentArea() async {
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

      return area;
    } catch (_) {
      return null;
    }
  }

  static Future<List<LocationSuggestion>> searchAreas(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return [];

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
        final title = _firstNotEmpty([
          trimmedQuery,
          place.name,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
        ]);
        final subtitle = _joinUnique([
          place.name,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country,
        ], skip: title);

        if (title == null) continue;
        final key = '$title|$subtitle'.toLowerCase();
        if (!seen.add(key)) continue;

        suggestions.add(LocationSuggestion(title: title, subtitle: subtitle));
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

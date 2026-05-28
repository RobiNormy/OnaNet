import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NominatimPlace {
  final String displayName;
  final String shortName;
  final double lat;
  final double lng;

  const NominatimPlace({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lng,
  });

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    final full = json['display_name'] as String? ?? '';
    final short = full.split(',').first.trim();
    return NominatimPlace(
      displayName: full,
      shortName: short.isEmpty ? 'Selected place' : short,
      lat: double.parse(json['lat'] as String),
      lng: double.parse(json['lon'] as String),
    );
  }
}

class CoverageArea {
  final String name;
  final double latitude;
  final double longitude;
  final double radiusKm;

  const CoverageArea({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  LatLng get center => LatLng(latitude, longitude);

  bool covers(LatLng searchPoint) {
    final distanceKm = const Distance().as(
      LengthUnit.Kilometer,
      center,
      searchPoint,
    );
    return distanceKm <= radiusKm;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusKm': radiusKm,
  };

  factory CoverageArea.fromJson(Map<String, dynamic> json) {
    return CoverageArea(
      name: json['name'] as String? ?? 'Coverage area',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusKm: (json['radiusKm'] as num).toDouble(),
    );
  }
}

class CoverageSearch {
  static final Uri _nominatimUri = Uri.https(
    'nominatim.openstreetmap.org',
    '/search',
  );

  static Future<List<NominatimPlace>> searchPlaces(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return [];

    try {
      final uri = _nominatimUri.replace(
        queryParameters: {
          'q': _withKenyaBias(trimmedQuery),
          'format': 'jsonv2',
          'limit': '6',
          'addressdetails': '1',
          'countrycodes': 'ke',
        },
      );
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'OnaNet/1.0 provider coverage search'},
      );

      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(NominatimPlace.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<T> providersCovering<T>({
    required Iterable<T> providers,
    required LatLng searchPoint,
    required Iterable<CoverageArea> Function(T provider) coverageAreas,
  }) {
    return providers.where((provider) {
      return coverageAreas(provider).any((area) => area.covers(searchPoint));
    }).toList();
  }

  static String _withKenyaBias(String query) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.contains('kenya') || lowerQuery == 'ke') {
      return query;
    }
    return '$query, Kenya';
  }
}

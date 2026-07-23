import 'dart:convert';

import 'package:http/http.dart' as http;

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

  static String _withKenyaBias(String query) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.contains('kenya') || lowerQuery == 'ke') return query;
    return '$query, Kenya';
  }
}

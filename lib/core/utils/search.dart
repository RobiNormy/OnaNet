// Search and coverage lookup helpers shared across provider flows.
import 'package:ona_net/core/network/api_client.dart';

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
    final full = (json['subtitle'] ?? json['display_name'] ?? '').toString();
    final short = (json['title'] ?? full.split(',').first).toString().trim();
    final latitude = json['latitude'] ?? json['lat'];
    final longitude = json['longitude'] ?? json['lon'];
    return NominatimPlace(
      displayName: full,
      shortName: short.isEmpty ? 'Selected place' : short,
      lat: latitude is num ? latitude.toDouble() : double.parse('$latitude'),
      lng: longitude is num ? longitude.toDouble() : double.parse('$longitude'),
    );
  }
}

class CoverageSearch {
  static Future<List<NominatimPlace>> searchPlaces(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];

    try {
      final response = await sharedApiClient.get<dynamic>(
        '$onaNetApiBaseUrl/locations/autocomplete',
        queryParameters: {'text': trimmedQuery, 'limit': 6},
      );
      final body = response.data;
      if (body is! Map || body['results'] is! List) return [];
      return (body['results'] as List)
          .whereType<Map>()
          .map(
            (item) => NominatimPlace.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}

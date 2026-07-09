import 'dart:math' as math;

enum ProviderFilter { all, budget, fast, verified, fiber }

const providerFilterOptions = [
  ProviderFilter.all,
  ProviderFilter.budget,
  ProviderFilter.fast,
  ProviderFilter.verified,
  ProviderFilter.fiber,
];

String providerFilterLabel(ProviderFilter filter) {
  return switch (filter) {
    ProviderFilter.all => 'All',
    ProviderFilter.budget => 'Budget',
    ProviderFilter.fast => 'Fast',
    ProviderFilter.verified => 'Verified',
    ProviderFilter.fiber => 'Fiber',
  };
}

List<Map<String, dynamic>> filterProviders(
  List<Map<String, dynamic>> providers, {
  required ProviderFilter filter,
  double? userLatitude,
  double? userLongitude,
  String? userArea,
  bool restrictToUserArea = true,
}) {
  final enriched = providers
      .map(
        (provider) => enrichProvider(
          provider,
          userLatitude: userLatitude,
          userLongitude: userLongitude,
          userArea: userArea,
        ),
      )
      .where(
        (provider) =>
            !restrictToUserArea ||
            providerMatchesUserLocation(
              provider,
              userLatitude: userLatitude,
              userLongitude: userLongitude,
              userArea: userArea,
            ),
      )
      .toList();
  final fastThreshold = _fastThreshold(enriched);

  return enriched.where((provider) {
    return switch (filter) {
      ProviderFilter.all => true,
      ProviderFilter.budget => hasBudgetPackage(provider),
      ProviderFilter.fast => isFastProvider(provider, fastThreshold),
      ProviderFilter.verified => isVerifiedProvider(provider),
      ProviderFilter.fiber => isFiberProvider(provider),
    };
  }).toList();
}

Map<String, dynamic> enrichProvider(
  Map<String, dynamic> provider, {
  double? userLatitude,
  double? userLongitude,
  String? userArea,
}) {
  final copy = Map<String, dynamic>.from(provider);
  final price = providerPrice(copy);
  final speed = providerSpeed(copy);
  final distanceKm = distanceToProviderKm(
    copy,
    userLatitude: userLatitude,
    userLongitude: userLongitude,
  );

  copy['price'] = price > 0 ? price : copy['price'];
  copy['speed'] = speed > 0 ? speed : copy['speed'];
  copy['verified'] = isVerifiedProvider(copy);
  if (distanceKm != null) {
    copy['distance'] = double.parse(distanceKm.toStringAsFixed(1));
    copy['distanceLabel'] = '${_formatDistance(distanceKm)} away';
  } else if (_matchesAreaText(copy, userArea)) {
    copy['distanceLabel'] = 'Covers ${userArea!.trim()}';
  } else {
    copy['distanceLabel'] = 'Coverage listed';
  }
  return copy;
}

String providerName(Map<String, dynamic> provider) {
  return (provider['name'] ??
          provider['provider_name'] ??
          provider['business_name'] ??
          'OnaNet Provider')
      .toString();
}

String providerType(Map<String, dynamic> provider) {
  return (provider['providerType'] ??
          provider['provider_type'] ??
          provider['service_type'] ??
          'Internet provider')
      .toString();
}

List<String> providerCoverageAreas(Map<String, dynamic> provider) {
  final value = provider['coverageAreas'] ?? provider['coverage_areas'];
  if (value is! List) return [];
  return value
      .map((area) {
        if (area is Map) {
          return area['name'] ?? area['area_name'] ?? area['areaName'];
        }
        return area;
      })
      .where((area) => area != null && area.toString().trim().isNotEmpty)
      .map((area) => area.toString().trim())
      .toList();
}

bool isVerifiedProvider(Map<String, dynamic> provider) {
  final status =
      (provider['document_verification_status'] ??
              provider['verification_status'] ??
              provider['status'])
          ?.toString()
          .toLowerCase();
  return provider['verified'] == true ||
      provider['isVerified'] == true ||
      provider['is_verified'] == true ||
      provider['documents_verified'] == true ||
      status == 'verified' ||
      status == 'approved';
}

int providerSpeed(Map<String, dynamic> provider) {
  final speeds = <int>[
    _asInt(provider['speed']),
    _asInt(provider['maxSpeed']),
    _asInt(provider['speed_mbps']),
    ...providerPackages(provider).map(
      (package) => _asInt(
        package['speed'] ?? package['speed_mbps'] ?? package['speedMbps'],
      ),
    ),
  ].where((speed) => speed > 0).toList();
  if (speeds.isEmpty) return 0;
  return speeds.reduce(math.max);
}

int providerPrice(Map<String, dynamic> provider) {
  final prices = <int>[
    _asInt(provider['price']),
    _asInt(provider['startingPrice']),
    _asInt(provider['monthly_price']),
    ...providerPackages(provider).map(
      (package) => _asInt(
        package['price'] ?? package['monthly_price'] ?? package['monthlyPrice'],
      ),
    ),
  ].where((price) => price > 0).toList();
  if (prices.isEmpty) return 0;
  return prices.reduce(math.min);
}

List<Map<String, dynamic>> providerPackages(Map<String, dynamic> provider) {
  final value = provider['packages'] ?? provider['providerPackages'];
  if (value is! List) return [];
  return value.whereType<Map>().map((item) {
    return item.map((key, value) => MapEntry(key.toString(), value));
  }).toList();
}

bool hasBudgetPackage(Map<String, dynamic> provider) {
  final prices = [
    providerPrice(provider),
    ...providerPackages(provider).map(
      (package) => _asInt(
        package['price'] ?? package['monthly_price'] ?? package['monthlyPrice'],
      ),
    ),
  ].where((price) => price > 0);
  return prices.any((price) => price >= 1000 && price <= 2000);
}

bool isFastProvider(Map<String, dynamic> provider, int threshold) {
  final speed = providerSpeed(provider);
  if (speed <= 0) return false;
  return speed >= threshold && _hasFriendlyFup(provider);
}

bool isFiberProvider(Map<String, dynamic> provider) {
  final searchable = [
    providerType(provider),
    providerName(provider),
    ...providerPackages(provider).expand(
      (package) => [
        package['name'],
        package['package_name'],
        package['connectionType'],
        package['connection_type'],
      ],
    ),
  ].join(' ').toLowerCase();
  return searchable.contains('fiber') ||
      searchable.contains('fibre') ||
      searchable.contains('ftth');
}

bool providerMatchesUserLocation(
  Map<String, dynamic> provider, {
  double? userLatitude,
  double? userLongitude,
  String? userArea,
}) {
  final hasGps = userLatitude != null && userLongitude != null;
  final hasArea = userArea != null && userArea.trim().isNotEmpty;
  if (!hasGps && !hasArea) return true;

  final coverage = _coverageMaps(provider);
  if (hasGps && coverage.any(_hasCoordinates)) {
    return coverage.any((area) {
      final latitude = _asDouble(area['latitude'] ?? area['lat']);
      final longitude = _asDouble(
        area['longitude'] ?? area['lng'] ?? area['lon'],
      );
      if (latitude == null || longitude == null) return false;
      final radius = _asDouble(area['radius_km'] ?? area['radiusKm']) ?? 5;
      final distance = _haversineKm(
        userLatitude,
        userLongitude,
        latitude,
        longitude,
      );
      return distance <= radius;
    });
  }

  return _matchesAreaText(provider, userArea);
}

double? distanceToProviderKm(
  Map<String, dynamic> provider, {
  double? userLatitude,
  double? userLongitude,
}) {
  if (userLatitude == null || userLongitude == null) return null;
  final distances = _coverageMaps(provider)
      .map((area) {
        final latitude = _asDouble(area['latitude'] ?? area['lat']);
        final longitude = _asDouble(
          area['longitude'] ?? area['lng'] ?? area['lon'],
        );
        if (latitude == null || longitude == null) return null;
        return _haversineKm(userLatitude, userLongitude, latitude, longitude);
      })
      .whereType<double>()
      .toList();
  if (distances.isEmpty) return null;
  return distances.reduce(math.min);
}

String providerDistanceLabel(Map<String, dynamic> provider) {
  final value = provider['distanceLabel'];
  if (value != null && value.toString().trim().isNotEmpty) {
    return value.toString();
  }
  final distance = _asDouble(provider['distance']);
  if (distance != null && distance > 0) {
    return '${_formatDistance(distance)} away';
  }
  return 'Coverage listed';
}

int _fastThreshold(List<Map<String, dynamic>> providers) {
  final speeds =
      providers.map(providerSpeed).where((speed) => speed > 0).toList()..sort();
  if (speeds.isEmpty) return 50;
  final topSpeed = speeds.last;
  return math.max(50, (topSpeed * 0.6).round());
}

bool _hasFriendlyFup(Map<String, dynamic> provider) {
  final fups = providerPackages(provider)
      .map(
        (package) =>
            (package['fairUsage'] ??
                    package['fair_usage_policy'] ??
                    package['fup'] ??
                    '')
                .toString()
                .toLowerCase(),
      )
      .where((fup) => fup.trim().isNotEmpty)
      .toList();
  if (fups.isEmpty) return true;
  return fups.any((fup) {
    if (fup.contains('unlimited') ||
        fup.contains('no cap') ||
        fup.contains('no limit') ||
        fup.contains('not specified')) {
      return true;
    }
    return !(fup.contains('throttle') ||
        fup.contains('capped') ||
        fup.contains('cap ') ||
        fup.contains('limit'));
  });
}

List<Map<String, dynamic>> _coverageMaps(Map<String, dynamic> provider) {
  final value =
      provider['coverageAreaDetails'] ??
      provider['coverage_area_details'] ??
      provider['coverageAreas'] ??
      provider['coverage_areas'];
  if (value is! List) return [];
  return value.whereType<Map>().map((item) {
    return item.map((key, value) => MapEntry(key.toString(), value));
  }).toList();
}

bool _hasCoordinates(Map<String, dynamic> area) {
  return _asDouble(area['latitude'] ?? area['lat']) != null &&
      _asDouble(area['longitude'] ?? area['lng'] ?? area['lon']) != null;
}

bool _matchesAreaText(Map<String, dynamic> provider, String? userArea) {
  final area = _normalize(userArea);
  if (area.isEmpty) return false;
  final candidates = [
    provider['primaryCity'],
    provider['primary_city'],
    provider['location'],
    provider['area'],
    ...providerCoverageAreas(provider),
  ].map((value) => _normalize(value));
  return candidates.any(
    (candidate) =>
        candidate.isNotEmpty &&
        (candidate.contains(area) || area.contains(candidate)),
  );
}

String _normalize(Object? value) {
  return (value ?? '')
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _asInt(Object? value) {
  if (value is num) return value.round();
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(value?.toString() ?? '');
  if (match == null) return 0;
  return double.tryParse(match.group(1)!)?.round() ?? 0;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return double.tryParse(text);
}

double _haversineKm(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const earthRadiusKm = 6371.0;
  final dLat = _degreesToRadians(latitudeB - latitudeA);
  final dLon = _degreesToRadians(longitudeB - longitudeA);
  final lat1 = _degreesToRadians(latitudeA);
  final lat2 = _degreesToRadians(latitudeB);
  final value =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;

String _formatDistance(double distanceKm) {
  if (distanceKm < 1) return '${(distanceKm * 1000).round()}m';
  return '${distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0)}km';
}

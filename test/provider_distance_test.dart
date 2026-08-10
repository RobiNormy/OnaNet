import 'package:flutter_test/flutter_test.dart';
import 'package:ona_net/core/utils/provider_filters.dart';

void main() {
  const embakasiLatitude = -1.3109463;
  const embakasiLongitude = 36.8924427;

  test(
    'labels the nearest real coverage area instead of a generic distance',
    () {
      final provider = enrichProvider(
        {
          'name': 'Watuu',
          'coverageAreaDetails': [
            {
              'name': 'Current location',
              'latitude': -1.311,
              'longitude': 36.8925,
              'radius_km': 1,
            },
            {
              'name': 'Kikuyu',
              'latitude': -1.2362919,
              'longitude': 36.590477,
              'radius_km': 3,
            },
          ],
        },
        userLatitude: embakasiLatitude,
        userLongitude: embakasiLongitude,
      );

      expect(provider['distance'], closeTo(34.6, 0.3));
      expect(provider['distanceLabel'], contains('to Kikuyu'));
    },
  );

  test('keeps a numeric distance inside the coverage radius', () {
    final provider = enrichProvider(
      {
        'name': 'Nearby Net',
        'coverageAreaDetails': [
          {
            'name': 'Embakasi',
            'latitude': -1.311,
            'longitude': 36.8925,
            'radius_km': 1,
          },
        ],
      },
      userLatitude: embakasiLatitude,
      userLongitude: embakasiLongitude,
    );

    expect(provider['distanceLabel'], contains('to Embakasi'));
    expect(provider['distanceLabel'], isNot(contains('Covers your location')));
  });

  test('parses and formats comma-separated monthly prices', () {
    final provider = <String, dynamic>{
      'packages': [
        {'price': '1,000'},
        {'price': '2,500'},
      ],
    };

    expect(providerPrice(provider), 1000);
    expect(formatKesPrice(providerPrice(provider)), '1,000');
  });
}

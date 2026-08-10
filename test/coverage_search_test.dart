import 'package:flutter_test/flutter_test.dart';
import 'package:ona_net/core/utils/search.dart';

void main() {
  test('parses a coverage search result', () {
    final place = NominatimPlace.fromJson({
      'display_name': 'Westlands, Nairobi, Kenya',
      'lat': '-1.2676',
      'lon': '36.8108',
    });

    expect(place.shortName, 'Westlands');
    expect(place.lat, -1.2676);
    expect(place.lng, 36.8108);
  });
}



class NominatimPlace {
  final String displayName;
  final String shortName;
  final double lat;
  final double lng;

  NominatimPlace({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lng,
  });

  factory NominatimPlace.fromJson(Map<String,dynamic> json){
    final full = json['display_name'] as String;
    final short = full.split(',').first.trim();
    return NominatimPlace(
      displayName: full,
      shortName: short,
      lat: double.parse(json['lat'] as String),
      lng: double.parse(json['lon'] as String),
    );
  }
}



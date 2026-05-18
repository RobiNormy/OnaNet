class Provider {
  final String id;
  final String name;
  final String initials;
  final int avatorColor;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final double startingPrice;
  final int maxSpeed;
  final double distanceKm;
  final List <String> coverageAreas;
  final String providerType;

  const Provider({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatorColor,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.startingPrice,
    required this.maxSpeed,
    required this.distanceKm,
    required this.coverageAreas,
    required this.providerType,
}
);

}
enum NearbyPlaceType { masjid, halalFood }

class NearbyPlace {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String? address;
  final String? subtitle;
  final NearbyPlaceType type;
  final Map<String, String> tags;

  const NearbyPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.type,
    this.address,
    this.subtitle,
    this.tags = const {},
  });

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
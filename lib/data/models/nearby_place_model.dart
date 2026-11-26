enum NearbyPlaceType { masjid, halalFood }

/// Provenance label for observability (cache / Geoapify / TomTom / Overpass).
enum NearbyPlaceSource {
  cache,
  geoapify,
  tomtom,
  overpass,
}

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
  final NearbyPlaceSource? source;

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
    this.source,
  });

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
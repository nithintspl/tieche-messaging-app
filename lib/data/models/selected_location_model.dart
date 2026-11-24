class SelectedLocation {
  final double latitude;
  final double longitude;
  final String displayName;
  final String? locality;
  final String? country;

  const SelectedLocation({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    this.locality,
    this.country,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'displayName': displayName,
        'locality': locality,
        'country': country,
      };

  factory SelectedLocation.fromJson(Map<String, dynamic> json) {
    return SelectedLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      displayName: json['displayName'] as String,
      locality: json['locality'] as String?,
      country: json['country'] as String?,
    );
  }
}
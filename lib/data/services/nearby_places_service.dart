import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nearby_place_model.dart';

class NearbyPlacesService {
  NearbyPlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _defaultRadiusMeters = 5000;
  static const _cacheTtl = Duration(minutes: 30);

  static const _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  final Map<String, _CacheEntry> _memoryCache = {};

  String _gridKey(double lat, double lng, int radius, NearbyPlaceType type) {
    final roundedLat = (lat / 0.005).round() * 0.005;
    final roundedLng = (lng / 0.005).round() * 0.005;
    return '${type.name}_${roundedLat.toStringAsFixed(3)}_${roundedLng.toStringAsFixed(3)}_$radius';
  }

  Future<List<NearbyPlace>> fetchNearby({
    required double latitude,
    required double longitude,
    required NearbyPlaceType type,
    int radiusMeters = _defaultRadiusMeters,
  }) async {
    if (!_isValidCoordinate(latitude, longitude)) {
      throw ArgumentError('Invalid coordinates for nearby search');
    }

    final key = _gridKey(latitude, longitude, radiusMeters, type);

    final memory = _memoryCache[key];
    if (memory != null && !memory.isExpired) {
      return _attachDistances(memory.places, latitude, longitude);
    }

    final disk = await _readDiskCache(key);
    if (disk != null && !disk.isExpired) {
      _memoryCache[key] = disk;
      return _attachDistances(disk.places, latitude, longitude);
    }

    try {
      final places = await _queryOverpass(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        type: type,
      );
      final entry = _CacheEntry(places: places, storedAt: DateTime.now());
      _memoryCache[key] = entry;
      await _writeDiskCache(key, entry);
      return _attachDistances(places, latitude, longitude);
    } catch (e) {
      // No backend nearby-places API; rely on Overpass + cache only.
      rethrow;
    }
  }

  static bool _isValidCoordinate(double lat, double lng) {
    return lat.abs() > 1e-6 &&
        lng.abs() > 1e-6 &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  List<NearbyPlace> _attachDistances(
    List<NearbyPlace> places,
    double userLat,
    double userLng,
  ) {
    return places
        .map((p) {
          final distance = Geolocator.distanceBetween(userLat, userLng, p.latitude, p.longitude);
          return NearbyPlace(
            id: p.id,
            name: p.name,
            latitude: p.latitude,
            longitude: p.longitude,
            distanceMeters: distance,
            type: p.type,
            address: p.address,
            subtitle: p.subtitle,
            tags: p.tags,
          );
        })
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  Future<List<NearbyPlace>> _queryOverpass({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required NearbyPlaceType type,
  }) async {
    final query = _buildQuery(latitude, longitude, radiusMeters);

    Object? lastError;
    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'data=${Uri.encodeComponent(query)}',
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 429 || response.statusCode == 504) {
          lastError = Exception('Overpass ${response.statusCode}');
          continue;
        }
        if (response.statusCode != 200) {
          lastError = Exception('Overpass error ${response.statusCode}');
          continue;
        }

        return _parseOverpassJson(response.body, type);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Overpass request failed');
  }

  String _buildQuery(double lat, double lng, int radius) {
    return '''
[out:json][timeout:25];
(
  nwr["amenity"="place_of_worship"]["religion"="muslim"](around:$radius,$lat,$lng);
  nwr["diet:halal"~"^(yes|only)\$",i](around:$radius,$lat,$lng);
  nwr["halal"~"^(yes|only)\$",i](around:$radius,$lat,$lng);
  nwr["cuisine"~"halal",i](around:$radius,$lat,$lng);
);
out center body;
''';
  }

  List<NearbyPlace> _parseOverpassJson(String body, NearbyPlaceType type) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? [];

    final places = <NearbyPlace>[];
    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) continue;
      final el = raw;

      final tags = (el['tags'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          <String, String>{};

      final elementType = _classify(tags);
      if (elementType == null) continue;
      if (elementType != type) continue;

      final coords = _readCoordinates(el);
      if (coords == null) continue;
      final lat = coords.$1;
      final lng = coords.$2;

      final addressParts = [
        tags['addr:street'],
        tags['addr:city'],
        tags['addr:postcode'],
      ].whereType<String>().where((s) => s.isNotEmpty).toList();

      final name = _displayName(tags, elementType, addressParts);

      String? subtitle;
      if (elementType == NearbyPlaceType.masjid) {
        subtitle = tags['denomination'] ?? tags['religion'];
      } else {
        subtitle = tags['cuisine'] ?? tags['diet:halal'] ?? tags['halal'];
      }

      places.add(
        NearbyPlace(
          id: '${el['type']}_${el['id']}',
          name: name,
          latitude: lat,
          longitude: lng,
          distanceMeters: 0,
          type: elementType,
          address: addressParts.isEmpty ? null : addressParts.join(', '),
          subtitle: subtitle,
          tags: tags,
        ),
      );
    }
    return places;
  }

  NearbyPlaceType? _classify(Map<String, String> tags) {
    final isMasjid =
        tags['amenity'] == 'place_of_worship' && tags['religion']?.toLowerCase() == 'muslim';
    if (isMasjid) return NearbyPlaceType.masjid;

    final diet = tags['diet:halal']?.toLowerCase();
    final halal = tags['halal']?.toLowerCase();
    final cuisine = tags['cuisine']?.toLowerCase() ?? '';

    final isHalal = diet == 'yes' ||
        diet == 'only' ||
        halal == 'yes' ||
        halal == 'only' ||
        cuisine.contains('halal');

    if (isHalal) return NearbyPlaceType.halalFood;
    return null;
  }

  (double, double)? _readCoordinates(Map<String, dynamic> el) {
    final directLat = el['lat'];
    final directLon = el['lon'];
    if (directLat is num && directLon is num) {
      return (directLat.toDouble(), directLon.toDouble());
    }

    final center = el['center'];
    if (center is Map) {
      final cLat = center['lat'];
      final cLon = center['lon'];
      if (cLat is num && cLon is num) {
        return (cLat.toDouble(), cLon.toDouble());
      }
    }
    return null;
  }

  String _displayName(
    Map<String, String> tags,
    NearbyPlaceType type,
    List<String> addressParts,
  ) {
    final explicit = tags['name'];
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }

    final street = tags['addr:street'];
    if (type == NearbyPlaceType.masjid) {
      if (street != null && street.isNotEmpty) return 'Masjid — $street';
      return 'Masjid';
    }

    if (street != null && street.isNotEmpty) return 'Halal Restaurant — $street';
    if (tags['amenity'] == 'restaurant' || tags['amenity'] == 'fast_food') {
      return 'Halal Restaurant';
    }
    return 'Halal Restaurant';
  }

  // Backend nearby-places API not available — see commented _fetchPhpFallback below.
  //
  // Future<List<NearbyPlace>?> _fetchPhpFallback({ ... }) async { ... }

  Future<_CacheEntry?> _readDiskCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('overpass_cache_$key');
    if (raw == null) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final storedAt = DateTime.parse(map['storedAt'] as String);
      final placesJson = map['places'] as List<dynamic>;
      final places = placesJson.map((p) {
        final m = p as Map<String, dynamic>;
        return NearbyPlace(
          id: m['id'] as String,
          name: m['name'] as String,
          latitude: (m['latitude'] as num).toDouble(),
          longitude: (m['longitude'] as num).toDouble(),
          distanceMeters: (m['distanceMeters'] as num).toDouble(),
          type: NearbyPlaceType.values.byName(m['type'] as String),
          address: m['address'] as String?,
          subtitle: m['subtitle'] as String?,
        );
      }).toList();
      return _CacheEntry(places: places, storedAt: storedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskCache(String key, _CacheEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = json.encode({
      'storedAt': entry.storedAt.toIso8601String(),
      'places': entry.places
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'latitude': p.latitude,
              'longitude': p.longitude,
              'distanceMeters': p.distanceMeters,
              'type': p.type.name,
              'address': p.address,
              'subtitle': p.subtitle,
            },
          )
          .toList(),
    });
    await prefs.setString('overpass_cache_$key', payload);
  }
}

class _CacheEntry {
  _CacheEntry({required this.places, required this.storedAt});

  final List<NearbyPlace> places;
  final DateTime storedAt;

  bool get isExpired => DateTime.now().difference(storedAt) > NearbyPlacesService._cacheTtl;
}
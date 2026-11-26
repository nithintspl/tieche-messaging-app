import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/maps_api_config.dart';
import '../../core/utils/spatial_grid.dart';
import '../models/nearby_place_model.dart';

class NearbyPlacesService {
  NearbyPlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _defaultRadiusMeters = 5000;
  static const _apiTimeout = Duration(seconds: 6);
  static const _diskKeyPrefix = 'places_v2_cache_';

  static const _ttlMasjid = Duration(days: 7);
  static const _ttlHalal = Duration(days: 3);

  static const _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  final Map<String, _CacheEntry> _memoryCache = {};
  final Map<String, Future<List<NearbyPlace>>> _inFlight = {};

  Duration _ttlFor(NearbyPlaceType type) =>
      type == NearbyPlaceType.masjid ? _ttlMasjid : _ttlHalal;

  String _gridKey(double lat, double lng, int radius, NearbyPlaceType type) {
    final bucket = SpatialGrid.bucketKey(lat, lng);
    return '${type.name}_${bucket}_$radius';
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

    final existing = _inFlight[key];
    if (existing != null) {
      final places = await existing;
      return _attachDistances(places, latitude, longitude);
    }

    final future = _fetchNearbyPipeline(
      key: key,
      latitude: latitude,
      longitude: longitude,
      type: type,
      radiusMeters: radiusMeters,
    );
    _inFlight[key] = future;
    try {
      final places = await future;
      return _attachDistances(places, latitude, longitude);
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<List<NearbyPlace>> _fetchNearbyPipeline({
    required String key,
    required double latitude,
    required double longitude,
    required NearbyPlaceType type,
    required int radiusMeters,
  }) async {
    final ttl = _ttlFor(type);

    final memory = _memoryCache[key];
    if (memory != null && !memory.isExpired(ttl)) {
      _logTier('Cache');
      return _tagSource(memory.places, NearbyPlaceSource.cache);
    }

    final disk = await _readDiskCache(key);
    if (disk != null && !disk.isExpired(ttl)) {
      _memoryCache[key] = disk;
      _logTier('Cache');
      return _tagSource(disk.places, NearbyPlaceSource.cache);
    }

    final stale = disk ?? (memory != null && memory.isExpired(ttl) ? memory : null);

    List<NearbyPlace> places = [];
    NearbyPlaceSource? source;

    final geoPlaces = await _tryGeoapify(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      type: type,
    );

    if (geoPlaces != null && _geoapifyAcceptable(geoPlaces, type)) {
      places = geoPlaces;
      source = NearbyPlaceSource.geoapify;
      _logTier('Geoapify');
    } else {
      final tomtomPlaces = await _tryTomtom(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        type: type,
      );

      if (tomtomPlaces != null && tomtomPlaces.isNotEmpty) {
        places = tomtomPlaces;
        source = NearbyPlaceSource.tomtom;
        _logTier('TomTom');
      } else if (geoPlaces != null && geoPlaces.isNotEmpty) {
        places = geoPlaces;
        source = NearbyPlaceSource.geoapify;
        _logTier('Geoapify');
      } else {
        try {
          places = await _queryOverpass(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            type: type,
          );
          if (places.isNotEmpty) {
            source = NearbyPlaceSource.overpass;
            _logTier('Overpass');
          }
        } catch (e) {
          if (stale != null && stale.places.isNotEmpty) {
            _logTier('Cache (stale fallback)');
            return _tagSource(stale.places, NearbyPlaceSource.cache);
          }
          rethrow;
        }
      }
    }

    if (places.isEmpty) {
      if (stale != null && stale.places.isNotEmpty) {
        _logTier('Cache (stale fallback)');
        return _tagSource(stale.places, NearbyPlaceSource.cache);
      }
      return [];
    }

    final tagged = _tagSource(places, source!);
    final entry = _CacheEntry(places: tagged, storedAt: DateTime.now());
    _memoryCache[key] = entry;
    unawaited(_writeDiskCache(key, entry));
    return tagged;
  }

  bool _geoapifyAcceptable(List<NearbyPlace> places, NearbyPlaceType type) {
    if (type == NearbyPlaceType.masjid) return places.isNotEmpty;
    return places.length >= 3;
  }

  void _logTier(String tier) {
    debugPrint('[Places] Served from: $tier');
  }

  List<NearbyPlace> _tagSource(List<NearbyPlace> places, NearbyPlaceSource source) {
    return places
        .map(
          (p) => NearbyPlace(
            id: p.id,
            name: p.name,
            latitude: p.latitude,
            longitude: p.longitude,
            distanceMeters: p.distanceMeters,
            type: p.type,
            address: p.address,
            subtitle: p.subtitle,
            tags: p.tags,
            source: source,
          ),
        )
        .toList();
  }

  Future<List<NearbyPlace>?> _tryGeoapify({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required NearbyPlaceType type,
  }) async {
    if (!MapsApiConfig.hasGeoapify) return null;

    final categories = type == NearbyPlaceType.masjid
        ? 'religion.place_of_worship.islam'
        : 'catering.restaurant.halal,catering.fast_food.halal';

    final params = <String, String>{
      'categories': categories,
      'filter': 'circle:$longitude,$latitude,$radiusMeters',
      'bias': 'proximity:$longitude,$latitude',
      'limit': '25',
      'apiKey': MapsApiConfig.geoapifyApiKey,
    };

    if (type == NearbyPlaceType.halalFood) {
      params['conditions'] = 'diet.halal';
    }

    final uri = Uri.https('api.geoapify.com', '/v2/places', params);

    try {
      final response = await _client.get(uri).timeout(_apiTimeout);
      if (_isRetryableHttp(response.statusCode)) return null;
      if (response.statusCode != 200) return null;

      return _parseGeoapifyJson(response.body, type);
    } catch (_) {
      return null;
    }
  }

  List<NearbyPlace> _parseGeoapifyJson(String body, NearbyPlaceType type) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? [];
    final places = <NearbyPlace>[];

    for (final raw in features) {
      if (raw is! Map<String, dynamic>) continue;
      final props = raw['properties'] as Map<String, dynamic>? ?? {};
      final geometry = raw['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) continue;

      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final name = (props['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      final address = props['formatted'] as String? ?? props['address_line1'] as String?;
      final placeId = props['place_id']?.toString() ?? 'geoapify_${lat}_$lon';

      places.add(
        NearbyPlace(
          id: placeId,
          name: name,
          latitude: lat,
          longitude: lon,
          distanceMeters: 0,
          type: type,
          address: address,
          subtitle: props['categories'] as String?,
        ),
      );
    }
    return places;
  }

  Future<List<NearbyPlace>?> _tryTomtom({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required NearbyPlaceType type,
  }) async {
    if (!MapsApiConfig.hasTomtom) return null;

    final query = type == NearbyPlaceType.masjid ? 'mosque' : 'halal restaurant';
    final encodedQuery = Uri.encodeComponent(query);

    final params = <String, String>{
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'radius': radiusMeters.toString(),
      'limit': '25',
      'key': MapsApiConfig.tomtomApiKey,
    };
    if (type == NearbyPlaceType.masjid) {
      params['categorySet'] = '7339';
    }

    final uri = Uri.https('api.tomtom.com', '/search/2/search/$encodedQuery.json', params);

    try {
      final response = await _client.get(uri).timeout(_apiTimeout);
      if (_isRetryableHttp(response.statusCode)) return null;
      if (response.statusCode != 200) return null;

      return _parseTomtomJson(response.body, type);
    } catch (_) {
      return null;
    }
  }

  List<NearbyPlace> _parseTomtomJson(String body, NearbyPlaceType type) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>? ?? [];
    final places = <NearbyPlace>[];

    for (final raw in results) {
      if (raw is! Map<String, dynamic>) continue;
      final position = raw['position'] as Map<String, dynamic>?;
      if (position == null) continue;
      final lat = (position['lat'] as num?)?.toDouble();
      final lon = (position['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final poi = raw['poi'] as Map<String, dynamic>?;
      final name = (poi?['name'] as String?)?.trim() ??
          (raw['address'] as Map<String, dynamic>?)?['freeformAddress'] as String?;
      if (name == null || name.isEmpty) continue;

      final addressMap = raw['address'] as Map<String, dynamic>?;
      final address = addressMap?['freeformAddress'] as String?;
      final id = raw['id']?.toString() ?? 'tomtom_${lat}_$lon';

      places.add(
        NearbyPlace(
          id: id,
          name: name,
          latitude: lat,
          longitude: lon,
          distanceMeters: 0,
          type: type,
          address: address,
          subtitle: poi?['classifications']?.toString(),
        ),
      );
    }
    return places;
  }

  static bool _isRetryableHttp(int statusCode) {
    return statusCode == 401 ||
        statusCode == 403 ||
        statusCode == 429 ||
        statusCode >= 500;
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
            source: p.source,
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
    final query = _buildQuery(latitude, longitude, radiusMeters, type);

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

  String _buildQuery(double lat, double lng, int radius, NearbyPlaceType type) {
    if (type == NearbyPlaceType.masjid) {
      return '''
[out:json][timeout:25];
(
  nwr["amenity"="place_of_worship"]["religion"="muslim"](around:$radius,$lat,$lng);
);
out center body;
''';
    }
    return '''
[out:json][timeout:25];
(
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
      if (elementType == null || elementType != type) continue;

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

  Future<_CacheEntry?> _readDiskCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_diskKeyPrefix$key') ?? prefs.getString('overpass_cache_$key');
    if (raw == null) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final storedAt = DateTime.parse(map['storedAt'] as String);
      final placesJson = map['places'] as List<dynamic>;
      final places = placesJson.map((p) {
        final m = p as Map<String, dynamic>;
        NearbyPlaceSource? source;
        final sourceRaw = m['source'] as String?;
        if (sourceRaw != null) {
          try {
            source = NearbyPlaceSource.values.byName(sourceRaw);
          } catch (_) {}
        }
        return NearbyPlace(
          id: m['id'] as String,
          name: m['name'] as String,
          latitude: (m['latitude'] as num).toDouble(),
          longitude: (m['longitude'] as num).toDouble(),
          distanceMeters: (m['distanceMeters'] as num).toDouble(),
          type: NearbyPlaceType.values.byName(m['type'] as String),
          address: m['address'] as String?,
          subtitle: m['subtitle'] as String?,
          source: source,
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
              if (p.source != null) 'source': p.source!.name,
            },
          )
          .toList(),
    });
    await prefs.setString('$_diskKeyPrefix$key', payload);
  }
}

class _CacheEntry {
  _CacheEntry({required this.places, required this.storedAt});

  final List<NearbyPlace> places;
  final DateTime storedAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(storedAt) > ttl;
}
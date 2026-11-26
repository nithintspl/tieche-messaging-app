import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/maps_api_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/spatial_grid.dart';
import '../models/selected_location_model.dart';

class LocationSearchResult {
  final double latitude;
  final double longitude;
  final String displayName;

  const LocationSearchResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

class LocationSearchService {
  static const _nominatimSearchBase = 'https://nominatim.openstreetmap.org/search';
  static const _nominatimReverseBase = 'https://nominatim.openstreetmap.org/reverse';
  static const _apiTimeout = Duration(seconds: 6);
  static const _forwardCacheTtl = Duration(days: 7);
  static const _reverseCacheTtl = Duration(days: 30);
  static const _minQueryLength = 3;
  static const _searchDebounce = Duration(milliseconds: 600);

  final http.Client _client;
  DateTime? _lastNominatimRequest;
  Timer? _debounce;
  final Map<String, Future<List<LocationSearchResult>>> _forwardInFlight = {};
  final Map<String, Future<SelectedLocation?>> _reverseInFlight = {};

  LocationSearchService({http.Client? client}) : _client = client ?? http.Client();

  Future<SelectedLocation?> fetchGpsLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final label = await reverseGeocode(position.latitude, position.longitude);
    return SelectedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      displayName: label?.displayName ?? 'Current location',
      locality: label?.locality,
      country: label?.country,
    );
  }

  Future<List<LocationSearchResult>> searchAddresses(
    String query, {
    Duration debounce = _searchDebounce,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < _minQueryLength) {
      return [];
    }

    final completer = Completer<List<LocationSearchResult>>();
    _debounce?.cancel();
    _debounce = Timer(debounce, () async {
      try {
        final results = await _searchForward(trimmed);
        if (!completer.isCompleted) completer.complete(results);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });
    return completer.future;
  }

  Future<List<LocationSearchResult>> _searchForward(String query) async {
    final cacheKey = 'fwd_${query.toLowerCase()}';
    final cached = await _readForwardCache(cacheKey);
    if (cached != null) {
      _logGeocodeTier('Cache');
      return cached;
    }

    final inFlight = _forwardInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _searchForwardPipeline(query, cacheKey);
    _forwardInFlight[cacheKey] = future;
    try {
      return await future;
    } finally {
      _forwardInFlight.remove(cacheKey);
    }
  }

  Future<List<LocationSearchResult>> _searchForwardPipeline(
    String query,
    String cacheKey,
  ) async {
    final geo = await _geoapifyForward(query);
    if (geo.isNotEmpty) {
      _logGeocodeTier('Geoapify');
      await _writeForwardCache(cacheKey, geo);
      return geo;
    }

    final tomtom = await _tomtomForward(query);
    if (tomtom.isNotEmpty) {
      _logGeocodeTier('TomTom');
      await _writeForwardCache(cacheKey, tomtom);
      return tomtom;
    }

    final nominatim = await _nominatimSearch(query);
    if (nominatim.isNotEmpty) {
      _logGeocodeTier('Nominatim');
      await _writeForwardCache(cacheKey, nominatim);
    }
    return nominatim;
  }

  Future<SelectedLocation?> reverseGeocode(double lat, double lng) async {
    final bucket = SpatialGrid.bucketKey(lat, lng);
    final cacheKey = 'rev_$bucket';

    final cached = await _readReverseCache(cacheKey);
    if (cached != null) {
      _logGeocodeTier('Cache');
      return cached.copyAt(lat, lng);
    }

    final inFlight = _reverseInFlight[cacheKey];
    if (inFlight != null) {
      final hit = await inFlight;
      return hit?.copyAt(lat, lng);
    }

    final future = _reversePipeline(lat, lng, cacheKey);
    _reverseInFlight[cacheKey] = future;
    try {
      final result = await future;
      return result?.copyAt(lat, lng);
    } finally {
      _reverseInFlight.remove(cacheKey);
    }
  }

  Future<SelectedLocation?> _reversePipeline(double lat, double lng, String cacheKey) async {
    final geo = await _geoapifyReverse(lat, lng);
    if (geo != null) {
      _logGeocodeTier('Geoapify');
      await _writeReverseCache(cacheKey, geo);
      return geo;
    }

    final tomtom = await _tomtomReverse(lat, lng);
    if (tomtom != null) {
      _logGeocodeTier('TomTom');
      await _writeReverseCache(cacheKey, tomtom);
      return tomtom;
    }

    final nominatim = await _nominatimReverse(lat, lng);
    if (nominatim != null) {
      _logGeocodeTier('Nominatim');
      await _writeReverseCache(cacheKey, nominatim);
    }
    return nominatim;
  }

  Future<List<LocationSearchResult>> _geoapifyForward(String query) async {
    if (!MapsApiConfig.hasGeoapify) return [];

    final uri = Uri.https(
      'api.geoapify.com',
      '/v1/geocode/search',
      {
        'text': query,
        'limit': '5',
        'apiKey': MapsApiConfig.geoapifyApiKey,
      },
    );

    try {
      final response = await _client.get(uri).timeout(_apiTimeout);
      if (response.statusCode != 200) return [];
      return _parseGeoapifyFeatures(response.body);
    } catch (_) {
      return [];
    }
  }

  Future<SelectedLocation?> _geoapifyReverse(double lat, double lng) async {
    if (!MapsApiConfig.hasGeoapify) return null;

    final uri = Uri.https(
      'api.geoapify.com',
      '/v1/geocode/reverse',
      {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'apiKey': MapsApiConfig.geoapifyApiKey,
      },
    );

    try {
      final response = await _client.get(uri).timeout(_apiTimeout);
      if (response.statusCode != 200) return null;
      final results = _parseGeoapifyFeatures(response.body);
      if (results.isEmpty) return null;
      final top = results.first;
      return _locationFromResult(top);
    } catch (_) {
      return null;
    }
  }

  List<LocationSearchResult> _parseGeoapifyFeatures(String body) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? [];
    final results = <LocationSearchResult>[];

    for (final raw in features) {
      if (raw is! Map<String, dynamic>) continue;
      final props = raw['properties'] as Map<String, dynamic>? ?? {};
      final lat = (props['lat'] as num?)?.toDouble();
      final lon = (props['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final label = props['formatted'] as String? ??
          props['address_line1'] as String? ??
          props['city'] as String? ??
          'Result';

      results.add(
        LocationSearchResult(
          latitude: lat,
          longitude: lon,
          displayName: label,
        ),
      );
    }
    return results;
  }

  Future<List<LocationSearchResult>> _tomtomForward(String query) async {
    if (!MapsApiConfig.hasTomtom) return [];

    final encoded = Uri.encodeComponent(query);
    final uri = Uri.https(
      'api.tomtom.com',
      '/search/2/geocode/$encoded.json',
      {
        'limit': '5',
        'key': MapsApiConfig.tomtomApiKey,
      },
    );

    try {
      final response = await _client.get(uri).timeout(_apiTimeout);
      if (response.statusCode != 200) return [];
      return _parseTomtomResults(response.body);
    } catch (_) {
      return [];
    }
  }

  Future<SelectedLocation?> _tomtomReverse(double lat, double lng) async {
    if (!MapsApiConfig.hasTomtom) return null;

    final uri = Uri.https(
      'api.tomtom.com',
      '/search/2/reverseGeocode/${lat.toString()},${lng.toString()}.json',
      {'key': MapsApiConfig.tomtomApiKey},
    );

    try {
      final response = await _client.get(uri).timeout(_apiTimeout);
      if (response.statusCode != 200) return null;
      final results = _parseTomtomResults(response.body);
      if (results.isEmpty) return null;
      return _locationFromResult(results.first);
    } catch (_) {
      return null;
    }
  }

  List<LocationSearchResult> _parseTomtomResults(String body) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>? ?? [];
    final out = <LocationSearchResult>[];

    for (final raw in results) {
      if (raw is! Map<String, dynamic>) continue;
      final position = raw['position'] as Map<String, dynamic>?;
      if (position == null) continue;
      final lat = (position['lat'] as num?)?.toDouble();
      final lon = (position['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final address = raw['address'] as Map<String, dynamic>?;
      final label = address?['freeformAddress'] as String? ??
          address?['municipality'] as String? ??
          'Result';

      out.add(
        LocationSearchResult(
          latitude: lat,
          longitude: lon,
          displayName: label,
        ),
      );
    }
    return out;
  }

  SelectedLocation _locationFromResult(LocationSearchResult result) {
    final parts = result.displayName.split(',').map((s) => s.trim()).toList();
    final locality = parts.isNotEmpty ? parts.first : null;
    final country = parts.length > 1 ? parts.last : null;

    return SelectedLocation(
      latitude: result.latitude,
      longitude: result.longitude,
      displayName: result.displayName,
      locality: locality,
      country: country,
    );
  }

  Future<List<LocationSearchResult>> _nominatimSearch(String query) async {
    await _throttleNominatim();

    final uri = Uri.parse(_nominatimSearchBase).replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '5',
      },
    );

    final response = await _client.get(
      uri,
      headers: {
        'User-Agent': AppConstants.nominatimUserAgent,
        'Accept': 'application/json',
      },
    ).timeout(_apiTimeout);

    if (response.statusCode != 200) {
      throw Exception('Location search unavailable (${response.statusCode})');
    }

    final list = json.decode(response.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return LocationSearchResult(
        latitude: double.parse(map['lat'] as String),
        longitude: double.parse(map['lon'] as String),
        displayName: map['display_name'] as String? ?? query,
      );
    }).toList();
  }

  Future<SelectedLocation?> _nominatimReverse(double lat, double lng) async {
    await _throttleNominatim();

    final uri = Uri.parse(_nominatimReverseBase).replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'json',
      },
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': AppConstants.nominatimUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(_apiTimeout);

      if (response.statusCode != 200) return null;
      final map = json.decode(response.body) as Map<String, dynamic>;
      final display = map['display_name'] as String? ?? 'Selected area';
      final address = map['address'] as Map<String, dynamic>?;

      return SelectedLocation(
        latitude: lat,
        longitude: lng,
        displayName: display,
        locality: address?['city'] as String? ?? address?['town'] as String?,
        country: address?['country'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _throttleNominatim() async {
    final now = DateTime.now();
    if (_lastNominatimRequest != null) {
      final elapsed = now.difference(_lastNominatimRequest!);
      if (elapsed < const Duration(seconds: 1)) {
        await Future<void>.delayed(const Duration(seconds: 1) - elapsed);
      }
    }
    _lastNominatimRequest = DateTime.now();
  }

  void _logGeocodeTier(String tier) {
    debugPrint('[Geocode] Served from: $tier');
  }

  Future<List<LocationSearchResult>?> _readForwardCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('geocode_cache_$key');
    if (raw == null) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final storedAt = DateTime.parse(map['storedAt'] as String);
      if (DateTime.now().difference(storedAt) > _forwardCacheTtl) return null;
      final list = map['results'] as List<dynamic>;
      return list
          .map(
            (e) => LocationSearchResult(
              latitude: (e['lat'] as num).toDouble(),
              longitude: (e['lon'] as num).toDouble(),
              displayName: e['label'] as String,
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeForwardCache(String key, List<LocationSearchResult> results) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'geocode_cache_$key',
      json.encode({
        'storedAt': DateTime.now().toIso8601String(),
        'results': results
            .map(
              (r) => {
                'lat': r.latitude,
                'lon': r.longitude,
                'label': r.displayName,
              },
            )
            .toList(),
      }),
    );
  }

  Future<SelectedLocation?> _readReverseCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('geocode_cache_$key');
    if (raw == null) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final storedAt = DateTime.parse(map['storedAt'] as String);
      if (DateTime.now().difference(storedAt) > _reverseCacheTtl) return null;
      return SelectedLocation.fromJson(map['location'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeReverseCache(String key, SelectedLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'geocode_cache_$key',
      json.encode({
        'storedAt': DateTime.now().toIso8601String(),
        'location': location.toJson(),
      }),
    );
  }

  void dispose() => _debounce?.cancel();
}

extension on SelectedLocation {
  SelectedLocation copyAt(double lat, double lng) {
    return SelectedLocation(
      latitude: lat,
      longitude: lng,
      displayName: displayName,
      locality: locality,
      country: country,
    );
  }
}
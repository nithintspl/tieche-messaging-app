import 'dart:async';
import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
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
  static const _nominatimBase = 'https://nominatim.openstreetmap.org/search';

  final Geocoding _geocoding = Geocoding();

  DateTime? _lastNominatimRequest;
  Timer? _debounce;

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
    Duration debounce = const Duration(seconds: 1),
  }) async {
    final completer = Completer<List<LocationSearchResult>>();
    _debounce?.cancel();
    _debounce = Timer(debounce, () async {
      try {
        final results = await _search(query);
        if (!completer.isCompleted) completer.complete(results);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });
    return completer.future;
  }

  Future<List<LocationSearchResult>> _search(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final locations = await _geocoding.locationFromAddress(query);
      if (locations.isNotEmpty) {
        return locations
            .map(
              (l) => LocationSearchResult(
                latitude: l.latitude,
                longitude: l.longitude,
                displayName: query.trim(),
              ),
            )
            .take(5)
            .toList();
      }
    } catch (_) {
      // Fall through to Nominatim.
    }

    return _nominatimSearch(query);
  }

  Future<SelectedLocation?> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [
        if (p.locality?.isNotEmpty == true) p.locality!,
        if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
        if (p.country?.isNotEmpty == true) p.country!,
      ];
      return SelectedLocation(
        latitude: lat,
        longitude: lng,
        displayName: parts.isEmpty ? 'Selected area' : parts.join(', '),
        locality: p.locality,
        country: p.country,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<LocationSearchResult>> _nominatimSearch(String query) async {
    await _throttleNominatim();

    final uri = Uri.parse(_nominatimBase).replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '5',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': AppConstants.nominatimUserAgent,
        'Accept': 'application/json',
      },
    );

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

  void dispose() => _debounce?.cancel();
}
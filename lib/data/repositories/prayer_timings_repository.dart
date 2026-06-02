import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../models/prayer_time_model.dart';

abstract class PrayerRepository {
  Future<List<PrayerTime>> getPrayerTimings();
}

class MockPrayerRepository implements PrayerRepository {
  @override
  Future<List<PrayerTime>> getPrayerTimings() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      PrayerTime(name: 'FAJAR', time: '05:15 am'),
      PrayerTime(name: 'DUHR', time: '01:15 pm'),
      PrayerTime(name: 'JUMMA', time: '01:35 pm'),
      PrayerTime(name: 'ASR', time: '06:00 pm'),
      PrayerTime(name: 'MAGHRIB', time: '08:00 pm'),
      PrayerTime(name: 'ISHA', time: '09:30 pm'),
    ];
  }
}

class HttpPrayerRepository implements PrayerRepository {
  final http.Client _client;

  HttpPrayerRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> _getWithHostFallback(String endpoint) async {
    Object? lastError;

    for (final baseUrl in AppConstants.apiBaseUrls) {
      final url = Uri.parse('$baseUrl$endpoint');
      try {
        final response = await _client.get(url).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          return response;
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(
      'Network error: Failed to connect to prayer timings endpoint'
      '${lastError != null ? ' - $lastError' : ''}',
    );
  }

  @override
  Future<List<PrayerTime>> getPrayerTimings() async {
    try {
      final response = await _getWithHostFallback('/api/home/timings');

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        // Handle double-nested list [[...]] or single list [...]
        List<dynamic> listData;
        if (decoded is List) {
          if (decoded.isNotEmpty && decoded.first is List) {
            listData = decoded.first as List<dynamic>;
          } else {
            listData = decoded;
          }
        } else {
          throw Exception('Invalid response format: expected a JSON list');
        }

        return listData
            .map((jsonItem) => PrayerTime.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load prayer timings (Status Code: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

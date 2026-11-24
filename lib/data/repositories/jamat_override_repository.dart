import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../models/prayer_schedule_model.dart';

/// Committee masjid Jamat overrides from optional PHP backend.
abstract class JamatOverrideRepository {
  Future<Map<PrayerName, DateTime>?> fetchOverrides({
    required String masjidId,
    required DateTime date,
  });
}

class HttpJamatOverrideRepository implements JamatOverrideRepository {
  HttpJamatOverrideRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Map<PrayerName, DateTime>?> fetchOverrides({
    required String masjidId,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(
      '${AppConstants.baseApiUrl}/api/jamat-timings.php?masjid_id=$masjidId&date=$dateStr',
    );

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final timings = body['timings'];
      if (timings is! Map<String, dynamic>) return null;

      final result = <PrayerName, DateTime>{};
      for (final entry in timings.entries) {
        final prayer = _parsePrayerName(entry.key);
        if (prayer == null || entry.value is! String) continue;
        final parsed = DateTime.tryParse(entry.value as String);
        if (parsed != null) result[prayer] = parsed;
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  PrayerName? _parsePrayerName(String raw) {
    return switch (raw.toLowerCase()) {
      'fajr' => PrayerName.fajr,
      'dhuhr' => PrayerName.dhuhr,
      'asr' => PrayerName.asr,
      'maghrib' => PrayerName.maghrib,
      'isha' => PrayerName.isha,
      _ => null,
    };
  }
}

class NoOpJamatOverrideRepository implements JamatOverrideRepository {
  @override
  Future<Map<PrayerName, DateTime>?> fetchOverrides({
    required String masjidId,
    required DateTime date,
  }) async =>
      null;
}
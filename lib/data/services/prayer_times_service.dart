import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:http/http.dart' as http;

import '../models/prayer_schedule_model.dart';
import '../models/selected_location_model.dart';
import '../repositories/jamat_override_repository.dart';

class PrayerTimesService {
  PrayerTimesService({
    JamatOverrideRepository? jamatOverrideRepository,
    http.Client? client,
  })  : _jamatRepo = jamatOverrideRepository ?? NoOpJamatOverrideRepository(),
        _client = client ?? http.Client();

  final JamatOverrideRepository _jamatRepo;
  final http.Client _client;

  static const defaultJamatOffsetsMinutes = {
    PrayerName.fajr: 20,
    PrayerName.dhuhr: 15,
    PrayerName.asr: 15,
    PrayerName.maghrib: 10,
    PrayerName.isha: 15,
  };

  Future<DailyPrayerSchedule> loadSchedule({
    required SelectedLocation location,
    required Madhab madhab,
    String? committeeMasjidId,
    bool allowApiFallback = true,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      final schedule = await _calculateOffline(
        location: location,
        date: today,
        madhab: madhab,
        committeeMasjidId: committeeMasjidId,
      );
      return schedule;
    } catch (_) {
      if (!allowApiFallback) rethrow;
      return _fetchAlAdhan(
        location: location,
        madhab: madhab,
        committeeMasjidId: committeeMasjidId,
      );
    }
  }

  Future<DailyPrayerSchedule> _calculateOffline({
    required SelectedLocation location,
    required DateTime date,
    required Madhab madhab,
    String? committeeMasjidId,
  }) async {
    final coordinates = Coordinates(location.latitude, location.longitude);
    final params = CalculationMethodParameters.karachi()..madhab = madhab;

    final prayerTimes = PrayerTimes(
      date: date,
      coordinates: coordinates,
      calculationParameters: params,
    );

    final overrides = committeeMasjidId != null
        ? await _jamatRepo.fetchOverrides(masjidId: committeeMasjidId, date: date)
        : null;

    final entries = <PrayerSlot>[
      _slot(PrayerName.fajr, prayerTimes.fajr, location.longitude, overrides),
      _slot(PrayerName.sunrise, prayerTimes.sunrise, location.longitude, overrides,
          jamatSameAsAdhan: true),
      _slot(PrayerName.dhuhr, prayerTimes.dhuhr, location.longitude, overrides),
      _slot(PrayerName.asr, prayerTimes.asr, location.longitude, overrides),
      _slot(PrayerName.maghrib, prayerTimes.maghrib, location.longitude, overrides),
      _slot(PrayerName.isha, prayerTimes.isha, location.longitude, overrides),
    ];

    return _withNextPrayer(entries, now: DateTime.now());
  }

  PrayerSlot _slot(
    PrayerName name,
    DateTime utcTime,
    double longitude,
    Map<PrayerName, DateTime>? overrides, {
    bool jamatSameAsAdhan = false,
  }) {
    final adhan = _utcToLocalWallClock(utcTime, longitude);
    DateTime jamat;
    if (overrides != null && overrides.containsKey(name)) {
      jamat = overrides[name]!;
    } else if (jamatSameAsAdhan || name == PrayerName.sunrise) {
      jamat = adhan;
    } else {
      final offset = defaultJamatOffsetsMinutes[name] ?? 0;
      jamat = adhan.add(Duration(minutes: offset));
    }
    return PrayerSlot(name: name, adhan: adhan, jamat: jamat);
  }

  /// Converts adhan_dart UTC instants to approximate local civil time via longitude.
  DateTime _utcToLocalWallClock(DateTime utc, double longitude) {
    final utcNormalized = utc.isUtc ? utc : utc.toUtc();
    final offsetMinutes = (longitude / 15 * 60).round();
    return utcNormalized.add(Duration(minutes: offsetMinutes));
  }

  Future<DailyPrayerSchedule> _fetchAlAdhan({
    required SelectedLocation location,
    required Madhab madhab,
    String? committeeMasjidId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final school = madhab == Madhab.hanafi ? 1 : 0;
    final uri = Uri.parse(
      'https://api.aladhan.com/v1/timings/$timestamp'
      '?latitude=${location.latitude}&longitude=${location.longitude}'
      '&method=1&school=$school',
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('AlAdhan API error ${response.statusCode}');
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    final timings = (jsonBody['data'] as Map<String, dynamic>)['timings'] as Map<String, dynamic>;
    final today = DateTime.now();

    DateTime parseLocal(String hhmm) {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateTime(today.year, today.month, today.day, h, m);
    }

    final overrides = committeeMasjidId != null
        ? await _jamatRepo.fetchOverrides(masjidId: committeeMasjidId, date: today)
        : null;

    PrayerSlot build(PrayerName name, String key, {bool noJamatOffset = false}) {
      final adhan = parseLocal(timings[key] as String);
      DateTime jamat;
      if (overrides != null && overrides.containsKey(name)) {
        jamat = overrides[name]!;
      } else if (noJamatOffset) {
        jamat = adhan;
      } else {
        jamat = adhan.add(Duration(minutes: defaultJamatOffsetsMinutes[name] ?? 0));
      }
      return PrayerSlot(name: name, adhan: adhan, jamat: jamat);
    }

    final entries = [
      build(PrayerName.fajr, 'Fajr'),
      build(PrayerName.sunrise, 'Sunrise', noJamatOffset: true),
      build(PrayerName.dhuhr, 'Dhuhr'),
      build(PrayerName.asr, 'Asr'),
      build(PrayerName.maghrib, 'Maghrib'),
      build(PrayerName.isha, 'Isha'),
    ];

    return _withNextPrayer(entries, now: DateTime.now());
  }

  DailyPrayerSchedule _withNextPrayer(List<PrayerSlot> slots, {required DateTime now}) {
    final prayerSlots = slots.where((s) => s.name != PrayerName.sunrise).toList();
    PrayerSlot? next;
    for (final slot in prayerSlots) {
      if (slot.adhan.isAfter(now)) {
        next = slot;
        break;
      }
    }
    next ??= prayerSlots.first;
    final diff = next.adhan.isAfter(now) ? next.adhan.difference(now) : Duration.zero;

    final marked = slots
        .map(
          (s) => PrayerSlot(
            name: s.name,
            adhan: s.adhan,
            jamat: s.jamat,
            isNext: s.name == next?.name,
          ),
        )
        .toList();

    return DailyPrayerSchedule(
      slots: marked,
      nextPrayer: next.name,
      nextPrayerTime: next.adhan,
      timeUntilNext: diff,
    );
  }
}
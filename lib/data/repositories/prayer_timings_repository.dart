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

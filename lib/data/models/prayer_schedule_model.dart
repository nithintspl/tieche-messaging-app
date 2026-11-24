enum PrayerName {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha,
}

class PrayerSlot {
  final PrayerName name;
  final DateTime adhan;
  final DateTime jamat;
  final bool isNext;

  const PrayerSlot({
    required this.name,
    required this.adhan,
    required this.jamat,
    this.isNext = false,
  });

  String get label => switch (name) {
        PrayerName.fajr => 'Fajr',
        PrayerName.sunrise => 'Sunrise',
        PrayerName.dhuhr => 'Dhuhr',
        PrayerName.asr => 'Asr',
        PrayerName.maghrib => 'Maghrib',
        PrayerName.isha => 'Isha',
      };
}

class DailyPrayerSchedule {
  final List<PrayerSlot> slots;
  final PrayerName? nextPrayer;
  final DateTime? nextPrayerTime;
  final Duration? timeUntilNext;

  const DailyPrayerSchedule({
    required this.slots,
    this.nextPrayer,
    this.nextPrayerTime,
    this.timeUntilNext,
  });
}
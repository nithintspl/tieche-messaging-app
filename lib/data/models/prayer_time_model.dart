class PrayerTime {
  final String name;
  final String time;

  PrayerTime({
    required this.name,
    required this.time,
  });

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String? ?? '').trim();
    String time24 = (json['time'] as String? ?? '').trim();
    
    // Convert 24-hour time to 12-hour format with AM/PM
    String time12 = time24;
    try {
      final parts = time24.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1].trim();
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        time12 = '$hour:$minute $period';
      }
    } catch (_) {
      // Keep original format if parsing fails
    }

    return PrayerTime(
      name: name,
      time: time12,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'time': time,
    };
  }
}

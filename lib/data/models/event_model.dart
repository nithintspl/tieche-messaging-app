import '../../core/constants/app_constants.dart';

class Event {
  final String id;
  final String title;
  final DateTime date;
  final String time;
  final String location;
  final String description;
  final String? imageUrl;

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.description,
    this.imageUrl,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // Determine title
    final title = (json['title'] ?? json['name'] ?? '') as String;
    
    // Determine date
    final dateStr = (json['date'] ?? json['startDate'] ?? DateTime.now().toIso8601String()) as String;
    final date = DateTime.parse(dateStr);

    // Determine imageUrl
    String? imageUrl = json['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.startsWith('/')) {
      imageUrl = '${AppConstants.baseApiUrl}$imageUrl';
    }

    // Determine description
    final description = (json['description'] ?? '') as String;

    // Try to extract time and location from description
    String extractedTime = json['time'] as String? ?? '';
    String extractedLocation = json['location'] as String? ?? '';

    if (extractedTime.isEmpty) {
      final desc = description.trim();
      final timeRegex = RegExp(r'\b\d{1,2}(?::\d{2})?\s*(?:AM|PM|a\.m\.|p\.m\.|am|pm)\b', caseSensitive: false);
      final timeMatch = timeRegex.firstMatch(desc);
      if (timeMatch != null) {
        extractedTime = timeMatch.group(0)!;
      } else if (desc.toLowerCase().contains('after salat ul maghrib') || desc.toLowerCase().contains('after maghrib')) {
        extractedTime = 'After Maghrib';
      } else {
        extractedTime = 'See Description';
      }
    }

    if (extractedLocation.isEmpty) {
      final desc = description.trim();
      final atIndex = desc.toLowerCase().indexOf(' at ');
      if (atIndex != -1) {
        String locPart = desc.substring(atIndex + 4).trim();
        if (locPart.endsWith('.')) {
          locPart = locPart.substring(0, locPart.length - 1).trim();
        }
        extractedLocation = locPart;
      } else {
        extractedLocation = 'Masjid Omar Moorpark';
      }
    }

    return Event(
      id: (json['id'] ?? '').toString(),
      title: title,
      date: date,
      time: extractedTime,
      location: extractedLocation,
      description: description,
      imageUrl: imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'time': time,
      'location': location,
      'description': description,
      'imageUrl': imageUrl,
    };
  }
}

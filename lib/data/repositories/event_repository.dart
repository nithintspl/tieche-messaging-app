import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../models/event_model.dart';

abstract class EventRepository {
  Future<List<Event>> getUpcomingEvents();
}

class MockEventRepository implements EventRepository {
  @override
  Future<List<Event>> getUpcomingEvents() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return [
      Event(
        id: 'e1',
        title: 'Weekly Community Gathering',
        date: DateTime.now().add(const Duration(days: 3)),
        time: '09:00 AM - 11:30 AM',
        location: 'Main Fellowship Hall, 100 greenway st',
        description: 'A morning filled with inspirational reflections, music, and a chance to meet fellow community members. Refreshments will be served after the main session in the courtyard. All are welcome, bring your family and friends!',
        imageUrl: 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?w=800&auto=format&fit=crop&q=60',
      ),
      Event(
        id: 'e2',
        title: 'Youth Leadership Seminar',
        date: DateTime.now().add(const Duration(days: 5)),
        time: '06:00 PM - 08:30 PM',
        location: 'Education Wing, Hall B',
        description: 'Empowering the next generation with values-based leadership skills, teamwork exercises, and career planning insights. Mentorship signups are available at the end of the seminar.',
        imageUrl: 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800&auto=format&fit=crop&q=60',
      ),
      Event(
        id: 'e3',
        title: 'Community Clean-up & Tree Planting',
        date: DateTime.now().add(const Duration(days: 14)),
        time: '08:00 AM - 12:00 PM',
        location: 'Oakridge Park (Main Gate)',
        description: 'Join hands to clean our local park and plant fifty new native trees. Shovels, compost, saplings, and light lunch will be provided. Wear sturdy shoes and bring water!',
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&auto=format&fit=crop&q=60',
      ),
    ];
  }
}

class HttpEventRepository implements EventRepository {
  final http.Client _client;

  HttpEventRepository({http.Client? client}) : _client = client ?? http.Client();

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
      'Network error: Failed to connect to events endpoint'
      '${lastError != null ? ' - $lastError' : ''}',
    );
  }

  @override
  Future<List<Event>> getUpcomingEvents() async {
    try {
      final response = await _getWithHostFallback('/api/home/events');

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
            .map((jsonItem) => Event.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load events (Status Code: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

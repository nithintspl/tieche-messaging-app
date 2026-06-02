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

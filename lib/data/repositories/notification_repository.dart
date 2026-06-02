import '../models/notification_model.dart';
import '../services/local_storage_service.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications();
  Future<void> markAsRead(String id);
}

class MockNotificationRepository implements NotificationRepository {
  final LocalStorageService _storage;

  MockNotificationRepository(this._storage);

  final List<AppNotification> _rawNotifications = [
    AppNotification(
      id: 'n1',
      title: 'Welcome to our Community App!',
      content: 'We are excited to connect with you. Use this app to browse the latest news, sermons, check upcoming events, and contact our team easily.',
      date: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'n2',
      title: 'Reminders: Community Cleanup',
      content: 'Don\'t forget! The tree planting event at Oakridge Park is happening next Saturday. Check upcoming events for location details and schedules.',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: 'n3',
      title: 'June Community Newsletter Out Now',
      content: 'The monthly newsletter has been published. Find information regarding recent administrative meetings, financial reports, and outreach efforts.',
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Future<List<AppNotification>> getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final readIds = _storage.getReadNotifications();

    // Map raw notifications, marking them read if their ID is in local storage
    return _rawNotifications.map((notif) {
      return notif.copyWith(isRead: readIds.contains(notif.id));
    }).toList();
  }

  @override
  Future<void> markAsRead(String id) async {
    final readIds = List<String>.from(_storage.getReadNotifications());
    if (!readIds.contains(id)) {
      readIds.add(id);
      await _storage.saveReadNotifications(readIds);
    }
  }
}

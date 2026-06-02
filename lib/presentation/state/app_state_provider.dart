import 'package:flutter/material.dart';
import '../../data/models/carousel_item_model.dart';
import '../../data/models/message_model.dart';
import '../../data/models/event_model.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/prayer_time_model.dart';
import '../../data/repositories/messaging_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/prayer_timings_repository.dart';

class AppStateProvider extends ChangeNotifier {
  final MessagingRepository _messagingRepository;
  final EventRepository _eventRepository;
  final NotificationRepository _notificationRepository;
  final PrayerRepository _prayerRepository;

  List<CarouselItem> _carouselItems = [];
  List<Message> _messages = [];
  List<Event> _events = [];
  List<AppNotification> _notifications = [];
  List<PrayerTime> _prayerTimings = [];

  bool _isLoading = false;
  String? _errorMessage;

  AppStateProvider({
    required MessagingRepository messagingRepository,
    required EventRepository eventRepository,
    required NotificationRepository notificationRepository,
    required PrayerRepository prayerRepository,
  })  : _messagingRepository = messagingRepository,
        _eventRepository = eventRepository,
        _notificationRepository = notificationRepository,
        _prayerRepository = prayerRepository;

  List<CarouselItem> get carouselItems => _carouselItems;
  List<Message> get messages => _messages;
  List<Event> get events => _events;
  List<AppNotification> get notifications => _notifications;
  List<PrayerTime> get prayerTimings => _prayerTimings;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  Future<void> fetchAllData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Run parallel fetches for better performance
      final results = await Future.wait([
        _messagingRepository.getCarouselItems(),
        _messagingRepository.getLatestMessages(),
        _eventRepository.getUpcomingEvents(),
        _notificationRepository.getNotifications(),
        _prayerRepository.getPrayerTimings(),
      ]);

      _carouselItems = results[0] as List<CarouselItem>;
      _messages = results[1] as List<Message>;
      _events = results[2] as List<Event>;
      _notifications = results[3] as List<AppNotification>;
      _prayerTimings = results[4] as List<PrayerTime>;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    try {
      // Find the index of the notification and update local model first
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index].isRead = true;
        notifyListeners(); // Immediate local UI response

        // Persist change
        await _notificationRepository.markAsRead(id);
      }
    } catch (_) {
      // Fail silently or handle error
    }
  }
}

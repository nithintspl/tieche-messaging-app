import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/navigation/app_routes.dart';

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _launchedFromNotification = false;

  static bool get _supportsFcm =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// `true` when the app was opened from a terminated state via a notification tap.
  static bool get launchedFromNotification => _launchedFromNotification;

  /// Requests notification permission (iOS), subscribes to the topic, and wires tap → home navigation.
  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;

    if (!_supportsFcm) return;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _messaging.subscribeToTopic(AppConstants.fcmTopicNewTopic);

    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      _navigateToHome();
    });

    final initialMessage = await _messaging.getInitialMessage();
    _launchedFromNotification = initialMessage != null;
  }

  static void _navigateToHome() {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToHome());
      return;
    }

    navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }
}
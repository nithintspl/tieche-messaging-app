import 'package:flutter/material.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/notifications_screen.dart';
import '../../presentation/screens/message_details_screen.dart';
import '../../presentation/screens/event_details_screen.dart';
import '../../presentation/screens/contact_us_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../data/models/message_model.dart';
import '../../data/models/event_model.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String notifications = '/notifications';
  static const String messageDetails = '/message-details';
  static const String eventDetails = '/event-details';
  static const String contactUs = '/contact-us';
  static const String login = '/login';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case messageDetails:
        final message = settings.arguments as Message;
        return MaterialPageRoute(
          builder: (_) => MessageDetailsScreen(message: message),
        );
      case eventDetails:
        final event = settings.arguments as Event;
        return MaterialPageRoute(
          builder: (_) => EventDetailsScreen(event: event),
        );
      case contactUs:
        return MaterialPageRoute(builder: (_) => const ContactUsScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

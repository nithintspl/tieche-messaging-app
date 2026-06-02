import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/navigation/app_routes.dart';
import 'data/services/local_storage_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/messaging_repository.dart';
import 'data/repositories/event_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'presentation/state/auth_provider.dart';
import 'presentation/state/app_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Storage Service
  final localStorageService = await LocalStorageService.init();

  // Initialize Repositories
  final authRepository = MockAuthRepository(localStorageService);
  final messagingRepository = MockMessagingRepository();
  final eventRepository = MockEventRepository();
  final notificationRepository = MockNotificationRepository(localStorageService);

  runApp(
    MultiProvider(
      providers: [
        // Providers for repositories
        Provider<LocalStorageService>.value(value: localStorageService),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<MessagingRepository>.value(value: messagingRepository),
        Provider<EventRepository>.value(value: eventRepository),
        Provider<NotificationRepository>.value(value: notificationRepository),

        // ChangeNotifierProviders for State Management
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository),
        ),
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => AppStateProvider(
            messagingRepository: messagingRepository,
            eventRepository: eventRepository,
            notificationRepository: notificationRepository,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Dynamically toggle based on OS settings
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

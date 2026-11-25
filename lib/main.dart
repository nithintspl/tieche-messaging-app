import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_routes.dart';
import 'data/services/local_storage_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/messaging_repository.dart';
import 'data/repositories/event_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/prayer_timings_repository.dart';
import 'data/repositories/jamat_override_repository.dart';
import 'data/services/location_search_service.dart';
import 'data/services/nearby_places_service.dart';
import 'data/services/prayer_times_service.dart';
import 'presentation/state/auth_provider.dart';
import 'presentation/state/app_state_provider.dart';
import 'presentation/state/qibla_compass_provider.dart';
import 'presentation/state/islamic_finder_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Local Storage Service
  final localStorageService = await LocalStorageService.init();

  // Initialize Repositories
  final authRepository = MockAuthRepository(localStorageService);
  final messagingRepository = HttpMessagingRepository();
  final eventRepository = HttpEventRepository();
  final notificationRepository = MockNotificationRepository(localStorageService);
  final prayerRepository = HttpPrayerRepository();
  final jamatOverrideRepository = HttpJamatOverrideRepository();

  runApp(
    MultiProvider(
      providers: [
        // Providers for repositories
        Provider<LocalStorageService>.value(value: localStorageService),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<MessagingRepository>.value(value: messagingRepository),
        Provider<EventRepository>.value(value: eventRepository),
        Provider<NotificationRepository>.value(value: notificationRepository),
        Provider<PrayerRepository>.value(value: prayerRepository),

        // ChangeNotifierProviders for State Management
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository),
        ),
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => AppStateProvider(
            messagingRepository: messagingRepository,
            eventRepository: eventRepository,
            notificationRepository: notificationRepository,
            prayerRepository: prayerRepository,
          ),
        ),
        ChangeNotifierProvider<QiblaCompassProvider>(
          create: (_) => QiblaCompassProvider(),
        ),
        ChangeNotifierProvider<IslamicFinderProvider>(
          create: (_) {
            final provider = IslamicFinderProvider(
              locationSearch: LocationSearchService(),
              prayerTimes: PrayerTimesService(
                jamatOverrideRepository: jamatOverrideRepository,
              ),
              nearbyPlaces: NearbyPlacesService(),
            );
            provider.initPreferences();
            return provider;
          },
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
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Dynamically toggle based on OS settings
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

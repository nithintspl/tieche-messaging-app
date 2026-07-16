import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state_provider.dart';
import '../state/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/navigation/app_routes.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_carousel.dart';
import '../widgets/message_card.dart';
import '../widgets/event_card.dart';
import '../widgets/prayer_timings_card.dart';
import '../../data/models/prayer_time_model.dart';
import 'contact_us_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppStateProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // List of screens for Bottom Navigation Bar
    final List<Widget> tabs = [
      _buildHomeTab(appState, theme),
      const ContactUsScreen(isTab: true),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: _currentTab == 1,
        toolbarHeight: _currentTab == 0 ? 64 : kToolbarHeight,
        leading: _currentTab == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentTab = 0;
                  });
                },
              )
            : null,
        title: _currentTab == 1
            ? const Text('Contact Us')
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // const AppLogo(
                  //   size: 28,
                  //   borderRadius: BorderRadius.all(Radius.circular(6)),
                  // ),
                  // const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppConstants.appName,
                      maxLines: 2,
                      style: theme.appBarTheme.titleTextStyle?.copyWith(
                        fontSize: 15,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          // Stack(
          //   alignment: Alignment.center,
          //   children: [
          //     IconButton(
          //       icon: const Icon(Icons.notifications_outlined, size: 28),
          //       onPressed: () {
          //         Navigator.pushNamed(context, AppRoutes.notifications);
          //       },
          //     ),
          //     if (appState.unreadNotificationCount > 0)
          //       Positioned(
          //         right: 8,
          //         top: 8,
          //         child: Container(
          //           padding: const EdgeInsets.all(4),
          //           decoration: const BoxDecoration(
          //             color: Colors.red,
          //             shape: BoxShape.circle,
          //           ),
          //           constraints: const BoxConstraints(
          //             minWidth: 16,
          //             minHeight: 16,
          //           ),
          //           child: Text(
          //             appState.unreadNotificationCount.toString(),
          //             style: const TextStyle(
          //               color: Colors.white,
          //               fontSize: 10,
          //               fontWeight: FontWeight.bold,
          //             ),
          //             textAlign: TextAlign.center,
          //           ),
          //         ),
          //       ),
          //   ],
          // ),
          // const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              accountName: Text(
                authProvider.isAuthenticated
                    ? authProvider.user!.name
                    : 'Guest User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                authProvider.isAuthenticated
                    ? authProvider.user!.email
                    : 'Sign in to access more features',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              selected: _currentTab == 0,
              onTap: () {
                setState(() {
                  _currentTab = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_support_outlined),
              title: const Text('Contact Us'),
              selected: _currentTab == 1,
              onTap: () {
                setState(() {
                  _currentTab = 1;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            // if (authProvider.isAuthenticated)
            //   ListTile(
            //     leading: const Icon(Icons.logout),
            //     title: const Text('Logout'),
            //     onTap: () {
            //       Navigator.pop(context);
            //       _handleLogout(context, authProvider);
            //     },
            //   )
            // else
            //   ListTile(
            //     leading: const Icon(Icons.login),
            //     title: const Text('Login'),
            //     onTap: () {
            //       Navigator.pop(context);
            //       Navigator.pushNamed(context, AppRoutes.login);
            //     },
            //   ),
            // const Divider(),
            ListTile(
              leading: const Icon(Icons.access_time_outlined),
              title: const Text('Daily Jammat Timings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.prayerTimings);
              },
            ),
          ],
        ),
      ),
      body: tabs[_currentTab],
    );
  }

  void _handleLogout(BuildContext context, AuthProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await provider.logout();
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildHomeTab(AppStateProvider appState, ThemeData theme) {
    if (appState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF2E7D32)),
        ),
      );
    }

    if (appState.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load community feed.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                appState.errorMessage!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => appState.fetchAllData(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => appState.fetchAllData(),
      color: theme.colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // 1. Image Carousel Section
          if (appState.carouselItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomCarousel(items: appState.carouselItems),
            ),

          // 2. Messages Section
          if (appState.messages.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Latest Messages',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...appState.messages.map((message) {
              return MessageCard(
                message: message,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.messageDetails,
                    arguments: message,
                  );
                },
              );
            }),
          ],

          // 3. Events Section
          if (appState.events.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Upcoming Events',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...appState.events.map((event) {
              return EventCard(
                event: event,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.eventDetails,
                    arguments: event,
                  );
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state_provider.dart';

class PrayerTimingsScreen extends StatelessWidget {
  const PrayerTimingsScreen({super.key});

  IconData _getPrayerIcon(String name) {
    final upperName = name.toUpperCase();
    if (upperName.contains('FAJAR') || upperName.contains('FAJR')) {
      return Icons.wb_twilight_outlined;
    } else if (upperName.contains('DUHR') || upperName.contains('DHUHR')) {
      return Icons.wb_sunny;
    } else if (upperName.contains('JUMMA')) {
      return Icons.mosque_outlined;
    } else if (upperName.contains('ASR')) {
      return Icons.wb_cloudy_outlined;
    } else if (upperName.contains('MAGHRIB')) {
      return Icons.nights_stay_outlined;
    } else if (upperName.contains('ISHA')) {
      return Icons.mode_night_outlined;
    }
    return Icons.access_time;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppStateProvider>(context);
    final timings = appState.prayerTimings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Jammat Timings'),
        elevation: 0,
      ),
      body: timings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No timings available.',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => appState.fetchAllData(),
              color: theme.colorScheme.primary,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Beautiful Mosque Header Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.mosque,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Masjid Omar Moorpark',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Join us for congregational prayers and gain blessings together.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Timings Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: timings.length,
                        separatorBuilder: (context, index) => Divider(
                          color: theme.colorScheme.outline.withOpacity(0.08),
                          height: 20,
                        ),
                        itemBuilder: (context, index) {
                          final timing = timings[index];
                          final icon = _getPrayerIcon(timing.name);
                          final isJumma = timing.name.toUpperCase().contains('JUMMA');

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                // Icon Circle
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isJumma
                                        ? theme.colorScheme.primary.withOpacity(0.15)
                                        : theme.colorScheme.primaryContainer.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    icon,
                                    color: isJumma
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withOpacity(0.7),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                
                                // Prayer Name
                                Text(
                                  timing.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: isJumma
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                
                                // Jammat Time
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isJumma
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    timing.time,
                                    style: TextStyle(
                                      color: isJumma
                                          ? Colors.white
                                          : theme.colorScheme.primary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

import 'dart:io' show Platform;

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/nearby_place_model.dart';
import '../../data/services/location_search_service.dart';
import '../../data/models/prayer_schedule_model.dart';
import '../state/islamic_finder_provider.dart';
import '../widgets/app_toast.dart';

class IslamicFinderScreen extends StatefulWidget {
  const IslamicFinderScreen({super.key, required this.isTabActive});

  final bool isTabActive;

  @override
  State<IslamicFinderScreen> createState() => _IslamicFinderScreenState();
}

class _IslamicFinderScreenState extends State<IslamicFinderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTab());
  }

  @override
  void didUpdateWidget(covariant IslamicFinderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTabActive != widget.isTabActive) _syncTab();
  }

  void _syncTab() {
    context.read<IslamicFinderProvider>().setTabActive(widget.isTabActive);
  }

  @override
  void dispose() {
    context.read<IslamicFinderProvider>().setTabActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IslamicFinderProvider>(
      builder: (context, provider, _) {
        final toast = provider.consumeUserToast();
        if (toast != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) AppToast.showError(context, toast);
          });
        }

        return RefreshIndicator(
          onRefresh: provider.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _LocationBar(
                label: provider.location?.displayName ?? 'Set your location',
                loading: provider.loadingLocation,
                onGps: provider.useDeviceLocation,
                onSearch: () => _openSearchSheet(context, provider),
              ),
              const SizedBox(height: 12),
              _MadhabSelector(madhab: provider.madhab, onChanged: provider.setMadhab),
              const SizedBox(height: 12),
              _PrayerScheduleCard(
                schedule: provider.schedule,
                loading: provider.loadingPrayer,
                failed: provider.prayerLoadFailed,
                onRetry: provider.refreshAll,
              ),
              const SizedBox(height: 16),
              SegmentedButton<IslamicFinderPlaceMode>(
                segments: const [
                  ButtonSegment(
                    value: IslamicFinderPlaceMode.masjid,
                    label: Text('Masjids'),
                    icon: Icon(Icons.mosque_outlined),
                  ),
                  ButtonSegment(
                    value: IslamicFinderPlaceMode.halalFood,
                    label: Text('Halal Food'),
                    icon: Icon(Icons.restaurant_outlined),
                  ),
                ],
                selected: {provider.placeMode},
                onSelectionChanged: (set) => provider.setPlaceMode(set.first),
              ),
              const SizedBox(height: 12),
              if (provider.loadingPlaces)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (provider.placesLoadFailed)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          "Couldn't load nearby places",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.placeMode == IslamicFinderPlaceMode.masjid
                              ? 'Check your connection and try loading Masjids again.'
                              : 'Check your connection and try loading Halal food again.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: provider.refreshAll,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (provider.places.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      provider.location == null
                          ? 'Choose a location to discover nearby places.'
                          : 'No results found within 5 km.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...provider.places.map(
                  (place) => _NearbyPlaceCard(
                    place: place,
                    onDirections: () => _openDirections(place),
                    onRegisterMasjid: provider.placeMode == IslamicFinderPlaceMode.masjid
                        ? () => provider.selectCommitteeMasjid(place)
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSearchSheet(BuildContext context, IslamicFinderProvider provider) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _LocationSearchSheet(provider: provider),
    );
  }

  Future<void> _openDirections(NearbyPlace place) async {
    final url = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?daddr=${place.latitude},${place.longitude}')
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}',
          );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

class _LocationBar extends StatelessWidget {
  const _LocationBar({
    required this.label,
    required this.loading,
    required this.onGps,
    required this.onSearch,
  });

  final String label;
  final bool loading;
  final VoidCallback onGps;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.place_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (loading)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              IconButton(
                tooltip: 'Use GPS',
                onPressed: onGps,
                icon: const Icon(Icons.my_location),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: onSearch,
                icon: const Icon(Icons.search),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MadhabSelector extends StatelessWidget {
  const _MadhabSelector({required this.madhab, required this.onChanged});

  final Madhab madhab;
  final ValueChanged<Madhab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Asr calculation: '),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Shafi'),
          selected: madhab == Madhab.shafi,
          onSelected: (_) => onChanged(Madhab.shafi),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Hanafi'),
          selected: madhab == Madhab.hanafi,
          onSelected: (_) => onChanged(Madhab.hanafi),
        ),
      ],
    );
  }
}

class _PrayerScheduleCard extends StatelessWidget {
  const _PrayerScheduleCard({
    required this.schedule,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final DailyPrayerSchedule? schedule;
  final bool loading;
  final bool failed;
  final Future<void> Function() onRetry;

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
    }
    if (failed) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                "Couldn't load prayer times",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final currentSchedule = schedule;
    if (currentSchedule == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Prayer times will appear here.')));
    }

    final nextPrayer = currentSchedule.nextPrayer;
    final until = currentSchedule.timeUntilNext;
    final nextLabel = nextPrayer == null
        ? null
        : currentSchedule.slots
            .firstWhere((s) => s.name == nextPrayer, orElse: () => currentSchedule.slots.first)
            .label;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nextLabel != null && until != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Next: $nextLabel in ${_formatDuration(until)}',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            const SizedBox(height: 12),
            ...currentSchedule.slots.map<Widget>((slot) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        slot.label,
                        style: TextStyle(
                          fontWeight: slot.isNext ? FontWeight.bold : FontWeight.w600,
                          color: slot.isNext ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                    Text('Adhan ${_formatTime(slot.adhan)}'),
                    const SizedBox(width: 12),
                    Text(
                      slot.name == PrayerName.sunrise ? '' : 'Jamat ${_formatTime(slot.jamat)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _NearbyPlaceCard extends StatelessWidget {
  const _NearbyPlaceCard({
    required this.place,
    required this.onDirections,
    this.onRegisterMasjid,
  });

  final NearbyPlace place;
  final VoidCallback onDirections;
  final VoidCallback? onRegisterMasjid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            place.type == NearbyPlaceType.masjid ? Icons.mosque_outlined : Icons.restaurant_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${place.distanceLabel}${place.subtitle != null ? ' · ${place.subtitle}' : ''}'),
            if (place.address != null) Text(place.address!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        isThreeLine: place.address != null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: onDirections, child: const Text('Directions')),
            if (onRegisterMasjid != null)
              TextButton(onPressed: onRegisterMasjid, child: const Text('Jamat')),
          ],
        ),
      ),
    );
  }
}

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet({required this.provider});

  final IslamicFinderProvider provider;

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _controller = TextEditingController();
  List<LocationSearchResult> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String value) async {
    if (value.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await widget.provider.searchLocations(value);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      final toast = widget.provider.consumeUserToast();
      if (toast != null) AppToast.showError(context, toast);
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Search city or neighborhood',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _runSearch,
          ),
          if (_searching) const LinearProgressIndicator(),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.35,
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  title: Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    await widget.provider.selectSearchResult(item);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
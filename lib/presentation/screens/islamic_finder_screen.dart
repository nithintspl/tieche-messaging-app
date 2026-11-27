import 'dart:async';
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

const _horizontalMargin = 16.0;
const _sectionGap = 12.0;
const _cardInnerPadding = 14.0;
const _listItemGap = 10.0;
const _tabularFigures = [FontFeature.tabularFigures()];

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

  double _scrollBottomInset(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + _sectionGap;
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

        final bottomInset = _scrollBottomInset(context);

        return RefreshIndicator(
          onRefresh: provider.refreshAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_horizontalMargin, 12, _horizontalMargin, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _LocationBar(
                      label: provider.location?.displayName ?? 'Set your location',
                      loading: provider.loadingLocation,
                      onGps: provider.useDeviceLocation,
                      onSearch: () => _openSearchSheet(context, provider),
                    ),
                    const SizedBox(height: _sectionGap),
                    _MadhabSelector(madhab: provider.madhab, onChanged: provider.setMadhab),
                    const SizedBox(height: _sectionGap),
                    _PrayerScheduleCard(
                      schedule: provider.schedule,
                      loading: provider.loadingPrayer,
                      failed: provider.prayerLoadFailed,
                      onRetry: provider.refreshAll,
                    ),
                    const SizedBox(height: _sectionGap),
                    _PlaceModeToggle(
                      selected: provider.placeMode,
                      onChanged: provider.setPlaceMode,
                    ),
                    const SizedBox(height: 8),
                    _PlacesMetaRow(
                      placeMode: provider.placeMode,
                      count: provider.places.length,
                      showCount: !provider.loadingPlaces &&
                          !provider.placesLoadFailed &&
                          provider.places.isNotEmpty,
                    ),
                    const SizedBox(height: _sectionGap),
                  ]),
                ),
              ),
              ..._placesSlivers(context, provider, bottomInset),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _placesSlivers(
    BuildContext context,
    IslamicFinderProvider provider,
    double bottomInset,
  ) {
    if (provider.loadingPlaces) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    if (provider.placesLoadFailed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(_horizontalMargin, 0, _horizontalMargin, bottomInset),
            child: Center(
              child: _PlacesStatusCard(
                title: "Couldn't load nearby places",
                message: provider.placeMode == IslamicFinderPlaceMode.masjid
                    ? 'Check your connection and try loading Masjids again.'
                    : 'Check your connection and try loading Halal food again.',
                actionLabel: 'Retry',
                onAction: provider.refreshAll,
                icon: Icons.cloud_off_outlined,
              ),
            ),
          ),
        ),
      ];
    }

    if (provider.places.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(_horizontalMargin, 0, _horizontalMargin, bottomInset),
            child: Center(
              child: _PlacesStatusCard(
                title: provider.location == null ? 'No location set' : 'No results nearby',
                message: provider.location == null
                    ? 'Choose a location to discover nearby places.'
                    : 'No results found within 5 km.',
                icon: Icons.location_off_outlined,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(_horizontalMargin, 0, _horizontalMargin, bottomInset),
        sliver: SliverList.separated(
          itemCount: provider.places.length,
          separatorBuilder: (_, __) => const SizedBox(height: _listItemGap),
          itemBuilder: (context, index) {
            final place = provider.places[index];
            return _NearbyPlaceCard(
              place: place,
              onDirections: () => _openDirections(place),
              onRegisterMasjid: provider.placeMode == IslamicFinderPlaceMode.masjid
                  ? () => provider.selectCommitteeMasjid(place)
                  : null,
            );
          },
        ),
      ),
    ];
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.place_outlined, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              _IconTapTarget(tooltip: 'Use GPS', icon: Icons.my_location, onPressed: onGps),
              _IconTapTarget(tooltip: 'Search', icon: Icons.search, onPressed: onSearch),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconTapTarget extends StatelessWidget {
  const _IconTapTarget({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(icon, size: 22),
    );
  }
}

class _MadhabSelector extends StatelessWidget {
  const _MadhabSelector({required this.madhab, required this.onChanged});

  final Madhab madhab;
  final ValueChanged<Madhab> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Asr calculation:',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        ChoiceChip(
          label: const Text('Shafi'),
          visualDensity: VisualDensity.compact,
          selected: madhab == Madhab.shafi,
          onSelected: (_) => onChanged(Madhab.shafi),
        ),
        ChoiceChip(
          label: const Text('Hanafi'),
          visualDensity: VisualDensity.compact,
          selected: madhab == Madhab.hanafi,
          onSelected: (_) => onChanged(Madhab.hanafi),
        ),
      ],
    );
  }
}

class _PlaceModeToggle extends StatelessWidget {
  const _PlaceModeToggle({
    required this.selected,
    required this.onChanged,
  });

  final IslamicFinderPlaceMode selected;
  final ValueChanged<IslamicFinderPlaceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<IslamicFinderPlaceMode>(
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        segments: [
          ButtonSegment(
            value: IslamicFinderPlaceMode.masjid,
            label: const Text('Masjids'),
            icon: narrow ? null : const Icon(Icons.mosque_outlined, size: 18),
          ),
          ButtonSegment(
            value: IslamicFinderPlaceMode.halalFood,
            label: const Text('Halal Food'),
            icon: narrow ? null : const Icon(Icons.restaurant_outlined, size: 18),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (set) => onChanged(set.first),
      ),
    );
  }
}

class _PlacesMetaRow extends StatelessWidget {
  const _PlacesMetaRow({
    required this.placeMode,
    required this.count,
    required this.showCount,
  });

  final IslamicFinderPlaceMode placeMode;
  final int count;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = placeMode == IslamicFinderPlaceMode.masjid ? 'Masjids' : 'Halal food';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            '$label within 5 km',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        if (showCount) ...[
          const SizedBox(width: 8),
          _CountBadge(count: count),
        ],
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontFeatures: _tabularFigures,
        ),
      ),
    );
  }
}

class _PlacesStatusCard extends StatelessWidget {
  const _PlacesStatusCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    required this.icon,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(_cardInnerPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
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

  TextStyle? _timeStyle(ThemeData theme, {bool highlight = false}) {
    return theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: _tabularFigures,
      fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
      color: highlight ? theme.colorScheme.primary : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (failed) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(_cardInnerPadding),
          child: Column(
            children: [
              const Text(
                "Couldn't load prayer times",
                textAlign: TextAlign.center,
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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(_cardInnerPadding),
          child: Text('Prayer times will appear here.'),
        ),
      );
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
        padding: const EdgeInsets.all(_cardInnerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nextLabel != null && until != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Next: $nextLabel in ${_formatDuration(until)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: _tabularFigures,
                  ),
                ),
              ),
            if (nextLabel != null && until != null) const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text('Prayer', style: muted),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('Adhan', textAlign: TextAlign.end, style: muted),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('Jamat', textAlign: TextAlign.end, style: muted),
                  ),
                ],
              ),
            ),
            ...currentSchedule.slots.map<Widget>((slot) {
              final highlight = slot.isNext;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        slot.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                          color: highlight ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        _formatTime(slot.adhan),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        style: _timeStyle(theme, highlight: highlight),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        slot.name == PrayerName.sunrise ? '—' : _formatTime(slot.jamat),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        style: _timeStyle(theme, highlight: highlight)?.copyWith(
                          fontSize: theme.textTheme.bodySmall?.fontSize,
                        ),
                      ),
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
    final secondary = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(_cardInnerPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                place.type == NearbyPlaceType.masjid ? Icons.mosque_outlined : Icons.restaurant_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DistanceChip(label: place.distanceLabel),
                    ],
                  ),
                  if (place.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      place.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: secondary,
                    ),
                  ],
                  if (place.address != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      place.address!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: secondary,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onDirections,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(48, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Directions'),
                      ),
                      if (onRegisterMasjid != null)
                        TextButton(
                          onPressed: onRegisterMasjid,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(48, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Jamat'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  const _DistanceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: _tabularFigures,
          ),
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
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_runSearch(trimmed));
    });
  }

  Future<void> _runSearch(String value) async {
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
        left: _horizontalMargin,
        right: _horizontalMargin,
        bottom: MediaQuery.viewInsetsOf(context).bottom + _horizontalMargin,
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
            onChanged: _onQueryChanged,
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
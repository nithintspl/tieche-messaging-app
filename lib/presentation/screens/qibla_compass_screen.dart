import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../state/qibla_compass_provider.dart';
import '../widgets/qibla_dial_painter.dart';

class QiblaCompassScreen extends StatefulWidget {
  const QiblaCompassScreen({
    super.key,
    required this.isTabActive,
  });

  final bool isTabActive;

  @override
  State<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends State<QiblaCompassScreen>
    with WidgetsBindingObserver {
  bool _hapticArmed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLifecycle());
  }

  @override
  void didUpdateWidget(covariant QiblaCompassScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTabActive != widget.isTabActive) {
      _syncLifecycle();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    context.read<QiblaCompassProvider>().setForeground(foreground);
  }

  void _syncLifecycle() {
    final provider = context.read<QiblaCompassProvider>();
    provider.setTabActive(widget.isTabActive);
    provider.setForeground(
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  void _handleAlignmentHaptic(bool isAligned) {
    if (isAligned && _hapticArmed) {
      _hapticArmed = false;
      HapticFeedback.selectionClick();
      HapticFeedback.lightImpact();
    } else if (!isAligned) {
      _hapticArmed = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<QiblaCompassProvider>().setTabActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<QiblaCompassProvider>(
      builder: (context, provider, _) {
        _handleAlignmentHaptic(provider.isAligned);

        return Column(
          children: [
            if (provider.needsCalibration) _CalibrationBanner(provider: provider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (provider.isLoadingLocation)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    else if (provider.locationError != null)
                      _LocationErrorCard(provider: provider)
                    else ...[
                      Text(
                        provider.qiblaDirectionLabel,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        provider.isAligned
                            ? 'Aligned with Qibla'
                            : 'Rotate until the gold marker meets the top notch',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: provider.isAligned
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const Spacer(),
                    if (!provider.hasCompassSensor)
                      _NoSensorView(provider: provider, theme: theme)
                    else if (provider.permissionStatus == LocationPermission.denied ||
                        provider.permissionStatus == LocationPermission.deniedForever)
                      _PermissionDeniedView(theme: theme)
                    else
                      _CompassDial(provider: provider, theme: theme),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompassDial extends StatelessWidget {
  const _CompassDial({required this.provider, required this.theme});

  final QiblaCompassProvider provider;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final headingKey = provider.hasLiveHeading
        ? provider.heading.toStringAsFixed(1)
        : 'waiting';
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: CustomPaint(
                  key: ValueKey('dial_$headingKey'),
                  painter: QiblaDialPainter(
                    heading: provider.heading,
                    qiblaAngle: provider.qiblaAngle,
                    isAligned: provider.isAligned,
                    primaryColor: theme.colorScheme.primary,
                    surfaceColor: theme.colorScheme.surface,
                    onSurfaceColor: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mosque_outlined,
                    color: theme.colorScheme.primary.withValues(alpha: 0.85),
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.hasLiveHeading
                        ? '${provider.heading.toStringAsFixed(0)}°'
                        : '—°',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoSensorView extends StatelessWidget {
  const _NoSensorView({required this.provider, required this.theme});

  final QiblaCompassProvider provider;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_off_outlined, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'No compass sensor detected',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              provider.qiblaDirectionLabel,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Face this direction using a physical compass or landmarks. '
              'This device cannot show a live dial without a magnetometer.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Location access needed',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow location while using the app so we can compute the Qibla bearing for your position.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await Geolocator.openAppSettings();
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationErrorCard extends StatelessWidget {
  const _LocationErrorCard({required this.provider});

  final QiblaCompassProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.location_searching),
            const SizedBox(width: 12),
            Expanded(child: Text(provider.locationError!)),
            IconButton(
              onPressed: provider.retryLocation,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationBanner extends StatelessWidget {
  const _CalibrationBanner({required this.provider});

  final QiblaCompassProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.screen_rotation_alt, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calibrate compass',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Move your phone in a figure-8 pattern a few times while away from metal objects.',
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: provider.dismissCalibrationBanner,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
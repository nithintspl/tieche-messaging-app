import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

typedef CompassReading = ({
  double heading,
  int accuracy,
  bool isTrueNorth,
});

class QiblaCompassService {
  static const _eventChannel = EventChannel('com.tieche.messaging/qibla_compass');
  static const _methodChannel = MethodChannel('com.tieche.messaging/qibla_compass');
  static const _alpha = 0.15;
  static const _nativeWatchdog = Duration(seconds: 2);

  StreamSubscription<dynamic>? _nativeSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magnetSub;

  final _controller = StreamController<CompassReading>.broadcast();
  double _smoothedHeading = 0;
  bool _hasSmoothedHeading = false;
  bool _useDartFallback = false;

  Timer? _nativeWatchdogTimer;
  DateTime? _lastNativeEventAt;
  double? _lastNativeHeading;
  int _nativeEventCount = 0;

  List<double>? _lastAccel;
  List<double>? _lastMag;

  Stream<CompassReading> get readings => _controller.stream;

  Future<bool> checkHasCompassSensor() async {
    if (kIsWeb) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasCompassSensor');
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> start() async {
    if (kIsWeb) {
      _controller.add((heading: 0, accuracy: -1, isTrueNorth: false));
      return;
    }

    _useDartFallback = false;
    _nativeEventCount = 0;
    _lastNativeEventAt = null;
    _lastNativeHeading = null;
    _hasSmoothedHeading = false;
    await _startNative();
  }

  Future<void> _startNative() async {
    await _nativeSub?.cancel();
    _cancelNativeWatchdog();
    try {
      _nativeSub = _eventChannel.receiveBroadcastStream().listen(
        _onNativeEvent,
        onError: (Object error) {
          if (!_useDartFallback) {
            unawaited(_startDartFallback());
          }
        },
      );
      _startNativeWatchdog();
    } on MissingPluginException {
      await _startDartFallback();
    }
  }

  void _startNativeWatchdog() {
    _cancelNativeWatchdog();
    _nativeWatchdogTimer = Timer(_nativeWatchdog, () {
      if (_useDartFallback) return;

      final noEvents = _nativeEventCount == 0;
      final stuckAtZero = _nativeEventCount >= 5 &&
          (_lastNativeHeading == null || _lastNativeHeading!.abs() < 0.01);
      final stale = _lastNativeEventAt != null &&
          DateTime.now().difference(_lastNativeEventAt!) > _nativeWatchdog &&
          _nativeEventCount == 0;

      if (noEvents || stuckAtZero || stale) {
        unawaited(_startDartFallback());
      }
    });
  }

  void _cancelNativeWatchdog() {
    _nativeWatchdogTimer?.cancel();
    _nativeWatchdogTimer = null;
  }

  Future<void> _startDartFallback() async {
    if (_useDartFallback) return;
    _useDartFallback = true;
    _cancelNativeWatchdog();
    await _nativeSub?.cancel();
    _nativeSub = null;

    var hasSensor = false;
    try {
      await magnetometerEventStream().first.timeout(const Duration(seconds: 2));
      hasSensor = true;
    } catch (_) {
      hasSensor = false;
    }

    if (!hasSensor) {
      if (!_controller.isClosed) {
        _controller.add((heading: double.nan, accuracy: -1, isTrueNorth: false));
      }
      return;
    }

    _accelSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen((e) {
      _lastAccel = [e.x, e.y, e.z];
      _emitDartHeading();
    });

    _magnetSub = magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen((e) {
      _lastMag = [e.x, e.y, e.z];
      _emitDartHeading();
    });
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;
    final rawHeading = (event['heading'] as num?)?.toDouble();
    if (rawHeading == null) return;

    _nativeEventCount++;
    _lastNativeEventAt = DateTime.now();
    _lastNativeHeading = rawHeading;

    // Cancel watchdog once we receive a meaningful heading from native.
    if (_nativeEventCount > 2 && rawHeading.abs() > 0.01) {
      _cancelNativeWatchdog();
    }

    final accuracy = (event['accuracy'] as num?)?.toInt() ?? -1;
    final isTrueNorth = event['isTrueNorth'] as bool? ?? false;

    final heading = _smoothHeading(rawHeading);
    if (!_controller.isClosed) {
      _controller.add(
        (heading: heading, accuracy: accuracy, isTrueNorth: isTrueNorth),
      );
    }
  }

  void _emitDartHeading() {
    final accel = _lastAccel;
    final mag = _lastMag;
    if (accel == null || mag == null) return;

    final heading = _tiltCompensatedHeading(accel, mag);
    if (heading == null) return;

    final smoothed = _smoothHeading(heading);
    if (!_controller.isClosed) {
      _controller.add(
        (heading: smoothed, accuracy: 2, isTrueNorth: false),
      );
    }
  }

  double? _tiltCompensatedHeading(List<double> accel, List<double> mag) {
    final ax = accel[0];
    final ay = accel[1];
    final az = accel[2];
    final mx = mag[0];
    final my = mag[1];
    final mz = mag[2];

    final norm = math.sqrt(ax * ax + ay * ay + az * az);
    if (norm < 1e-6) return null;

    final axN = ax / norm;
    final ayN = ay / norm;
    final azN = az / norm;

    final dot = mx * axN + my * ayN + mz * azN;
    final mxProj = mx - axN * dot;
    final myProj = my - ayN * dot;

    var heading = math.atan2(-myProj, mxProj) * 180 / math.pi;
    if (heading < 0) heading += 360;
    return heading;
  }

  double _smoothHeading(double target) {
    if (!_hasSmoothedHeading) {
      _smoothedHeading = target;
      _hasSmoothedHeading = true;
      return target;
    }
    final delta = ((target - _smoothedHeading + 540) % 360) - 180;
    _smoothedHeading = (_smoothedHeading + _alpha * delta + 360) % 360;
    return _smoothedHeading;
  }

  static bool needsCalibration(int accuracy) {
    if (accuracy < 0) return true;
    if (!kIsWeb && Platform.isIOS) {
      return accuracy > 25;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return accuracy <= 1;
    }
    return false;
  }

  Future<void> stop() async {
    _cancelNativeWatchdog();
    await _nativeSub?.cancel();
    _nativeSub = null;
    await _accelSub?.cancel();
    _accelSub = null;
    await _magnetSub?.cancel();
    _magnetSub = null;
    _hasSmoothedHeading = false;
    _nativeEventCount = 0;
    _lastNativeHeading = null;
    _lastNativeEventAt = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
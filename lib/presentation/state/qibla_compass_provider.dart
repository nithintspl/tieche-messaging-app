import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/services/qibla_compass_service.dart';
import '../../data/services/qibla_location_service.dart';

class QiblaCompassProvider extends ChangeNotifier {
  QiblaCompassProvider()
      : _compassService = QiblaCompassService(),
        _locationService = QiblaLocationService();

  final QiblaCompassService _compassService;
  final QiblaLocationService _locationService;

  StreamSubscription<CompassReading>? _compassSub;
  bool _isActive = false;
  bool _isForeground = true;
  int _startGeneration = 0;

  double? _heading;
  bool _hasLiveHeading = false;
  double _qiblaAngle = 0;
  bool _isAligned = false;
  bool _needsCalibration = false;
  LocationPermission _permissionStatus = LocationPermission.denied;
  bool _hasCompassSensor = true;
  bool _isLoadingLocation = false;
  String? _locationError;
  double? _latitude;
  double? _longitude;
  bool _calibrationBannerDismissed = false;

  double get heading => _heading ?? 0;
  bool get hasLiveHeading => _hasLiveHeading;
  double get qiblaAngle => _qiblaAngle;
  bool get isAligned => _isAligned;
  bool get needsCalibration => _needsCalibration && !_calibrationBannerDismissed;
  LocationPermission get permissionStatus => _permissionStatus;
  bool get hasCompassSensor => _hasCompassSensor;
  bool get isLoadingLocation => _isLoadingLocation;
  String? get locationError => _locationError;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  String get qiblaDirectionLabel {
    final dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final index = ((_qiblaAngle + 11.25) % 360 / 22.5).floor() % 16;
    return '${_qiblaAngle.toStringAsFixed(1)}° ${dirs[index]} from True North';
  }

  void setTabActive(bool active) {
    if (_isActive == active) return;
    _isActive = active;
    if (_isActive && _isForeground) {
      unawaited(_start());
    } else {
      unawaited(_stop());
    }
  }

  void setForeground(bool foreground) {
    if (_isForeground == foreground) return;
    _isForeground = foreground;
    if (_isActive && _isForeground) {
      unawaited(_start());
    } else {
      unawaited(_stop());
    }
  }

  Future<void> _start() async {
    if (!_isActive || !_isForeground) return;

    final generation = ++_startGeneration;
    _hasCompassSensor = true;
    notifyListeners();

    await _refreshLocation();
    if (generation != _startGeneration || !_isActive || !_isForeground) return;

    _heading = null;
    _hasLiveHeading = false;
    notifyListeners();

    await _compassSub?.cancel();
    await _compassService.start();
    if (generation != _startGeneration || !_isActive || !_isForeground) {
      await _compassService.stop();
      return;
    }

    _compassSub = _compassService.readings.listen((reading) {
      if (reading.heading.isNaN) {
        _hasCompassSensor = false;
      } else {
        _heading = reading.heading;
        _hasLiveHeading = true;
        _needsCalibration = QiblaCompassService.needsCalibration(reading.accuracy);
        if (_needsCalibration) {
          _calibrationBannerDismissed = false;
        }
        _updateAlignment();
      }
      notifyListeners();
    });
  }

  Future<void> _stop() async {
    _startGeneration++;
    await _compassSub?.cancel();
    _compassSub = null;
    await _compassService.stop();
  }

  Future<void> _refreshLocation() async {
    _isLoadingLocation = true;
    _locationError = null;
    notifyListeners();

    if (!await _locationService.isLocationServiceEnabled()) {
      _locationError = 'Location services are disabled. Enable them to compute Qibla.';
      _isLoadingLocation = false;
      notifyListeners();
      return;
    }

    _permissionStatus = await _locationService.requestPermission();
    if (_permissionStatus == LocationPermission.denied ||
        _permissionStatus == LocationPermission.deniedForever) {
      _locationError = 'Location permission is required to calculate Qibla direction.';
      _isLoadingLocation = false;
      notifyListeners();
      return;
    }

    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      _locationError = 'Unable to determine your location. Try moving outdoors.';
      _isLoadingLocation = false;
      notifyListeners();
      return;
    }

    _latitude = position.latitude;
    _longitude = position.longitude;
    _qiblaAngle = _locationService.calculateQiblaBearing(
      position.latitude,
      position.longitude,
    );
    await _locationService.sendLocationToNative(position);
    _updateAlignment();
    _isLoadingLocation = false;
    notifyListeners();
  }

  void _updateAlignment() {
    final currentHeading = _heading;
    if (currentHeading == null) {
      _isAligned = false;
      return;
    }
    final delta = ((currentHeading - _qiblaAngle + 540) % 360) - 180;
    _isAligned = delta.abs() <= 3;
  }

  void dismissCalibrationBanner() {
    _calibrationBannerDismissed = true;
    notifyListeners();
  }

  Future<void> retryLocation() => _refreshLocation();

  @override
  void dispose() {
    unawaited(_stop());
    _compassService.dispose();
    super.dispose();
  }
}
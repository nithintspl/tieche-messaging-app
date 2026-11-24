import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class QiblaLocationService {
  static const _methodChannel = MethodChannel('com.tieche.messaging/qibla_compass');

  Future<LocationPermission> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  double calculateQiblaBearing(double latitude, double longitude) {
    return Qibla.qibla(Coordinates(latitude, longitude));
  }

  Future<void> sendLocationToNative(Position position) async {
    if (kIsWeb) return;
    try {
      await _methodChannel.invokeMethod<void>('setLocation', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': position.altitude,
      });
    } on PlatformException {
      // iOS ignores declination; Android uses GeomagneticField.
    }
  }
}
import 'dart:math' as math;

/// ~110 m cells at the equator when [decimals] is 3.
class SpatialGrid {
  SpatialGrid._();

  static const int defaultDecimals = 3;

  static double roundCoordinate(double value, {int decimals = defaultDecimals}) {
    final factor = math.pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }

  static String bucketKey(double latitude, double longitude, {int decimals = defaultDecimals}) {
    final lat = roundCoordinate(latitude, decimals: decimals);
    final lng = roundCoordinate(longitude, decimals: decimals);
    return '${lat.toStringAsFixed(decimals)}_${lng.toStringAsFixed(decimals)}';
  }
}
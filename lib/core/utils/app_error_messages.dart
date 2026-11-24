import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum FinderErrorContext {
  location,
  prayerTimes,
  nearbyPlaces,
  search,
  generic,
}

class AppErrorMessages {
  static String from(
    Object error, {
    FinderErrorContext context = FinderErrorContext.generic,
  }) {
    if (error is SocketException) {
      return switch (context) {
        FinderErrorContext.prayerTimes =>
          'No internet connection. Showing offline prayer times when available.',
        FinderErrorContext.nearbyPlaces =>
          'No internet connection. Could not load nearby places.',
        FinderErrorContext.search =>
          'No internet connection. Try again when you are back online.',
        FinderErrorContext.location => 'No internet connection. GPS may still work on device.',
        _ => 'No internet connection. Please check your network and try again.',
      };
    }

    if (error is TimeoutException) {
      return switch (context) {
        FinderErrorContext.nearbyPlaces =>
          'Map server is busy, please try again in a moment.',
        _ => 'The request timed out. Please try again.',
      };
    }

    if (error is PlatformException) {
      if (error.code == 'PERMISSION_DENIED' || error.message?.toLowerCase().contains('permission') == true) {
        return 'Location permission is needed to find nearby Masjids and Halal food.';
      }
      return 'Something went wrong on your device. Please try again.';
    }

    final message = error.toString().toLowerCase();
    if (message.contains('429') || message.contains('too many')) {
      return 'Map server is busy, please try again in a moment.';
    }
    if (message.contains('504') || message.contains('gateway timeout')) {
      return 'Map server is busy, please try again in a moment.';
    }
    if (message.contains('500') || message.contains('502') || message.contains('503')) {
      return 'The service is temporarily unavailable. Please try again later.';
    }
    if (message.contains('permission') || message.contains('denied')) {
      return 'Location permission is needed to find nearby Masjids and Halal food.';
    }

    return switch (context) {
      FinderErrorContext.prayerTimes => 'Could not load prayer times. Pull to refresh or try again.',
      FinderErrorContext.nearbyPlaces => 'Could not load nearby places. Please try again.',
      FinderErrorContext.search => 'Location search failed. Try a different city name.',
      FinderErrorContext.location => 'Could not read your location. Search for a city manually.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}
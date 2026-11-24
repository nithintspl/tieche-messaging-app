import 'dart:async';
import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_error_messages.dart';
import '../../data/models/nearby_place_model.dart';
import '../../data/models/prayer_schedule_model.dart';
import '../../data/models/selected_location_model.dart';
import '../../data/services/location_search_service.dart';
import '../../data/services/nearby_places_service.dart';
import '../../data/services/prayer_times_service.dart';

enum IslamicFinderPlaceMode { masjid, halalFood }

class IslamicFinderProvider extends ChangeNotifier {
  IslamicFinderProvider({
    required LocationSearchService locationSearch,
    required PrayerTimesService prayerTimes,
    required NearbyPlacesService nearbyPlaces,
  })  : _locationSearch = locationSearch,
        _prayerTimes = prayerTimes,
        _nearbyPlaces = nearbyPlaces;

  final LocationSearchService _locationSearch;
  final PrayerTimesService _prayerTimes;
  final NearbyPlacesService _nearbyPlaces;

  static const _keyLocation = 'islamic_finder_location';
  static const _keyMadhab = 'islamic_finder_madhab';

  bool _isTabActive = false;
  SelectedLocation? _location;
  DailyPrayerSchedule? _schedule;
  List<NearbyPlace> _places = [];
  IslamicFinderPlaceMode _placeMode = IslamicFinderPlaceMode.masjid;
  Madhab _madhab = Madhab.shafi;
  String? _selectedMasjidId;

  bool _loadingLocation = false;
  bool _loadingPrayer = false;
  bool _loadingPlaces = false;

  bool _prayerLoadFailed = false;
  bool _placesLoadFailed = false;

  String? _pendingUserToast;

  Timer? _countdownTimer;

  SelectedLocation? get location => _location;
  DailyPrayerSchedule? get schedule => _schedule;
  List<NearbyPlace> get places => _places;
  IslamicFinderPlaceMode get placeMode => _placeMode;
  Madhab get madhab => _madhab;
  bool get loadingLocation => _loadingLocation;
  bool get loadingPrayer => _loadingPrayer;
  bool get loadingPlaces => _loadingPlaces;
  bool get prayerLoadFailed => _prayerLoadFailed;
  bool get placesLoadFailed => _placesLoadFailed;

  String? consumeUserToast() {
    final message = _pendingUserToast;
    _pendingUserToast = null;
    return message;
  }

  void _queueToast(String message) {
    _pendingUserToast = message;
  }

  static bool _isValidLocation(SelectedLocation? location) {
    if (location == null) return false;
    return location.latitude.abs() > 1e-6 &&
        location.longitude.abs() > 1e-6 &&
        location.latitude >= -90 &&
        location.latitude <= 90;
  }

  Future<void> initPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final madhabRaw = prefs.getString(_keyMadhab);
    if (madhabRaw == 'hanafi') _madhab = Madhab.hanafi;

    final locRaw = prefs.getString(_keyLocation);
    if (locRaw != null) {
      try {
        final restored = SelectedLocation.fromJson(
          json.decode(locRaw) as Map<String, dynamic>,
        );
        if (_isValidLocation(restored)) _location = restored;
      } catch (_) {}
    }
  }

  void setTabActive(bool active) {
    if (_isTabActive == active) return;
    _isTabActive = active;
    if (_isTabActive) {
      unawaited(refreshAll());
      _startCountdownTimer();
    } else {
      _countdownTimer?.cancel();
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_schedule != null) notifyListeners();
    });
  }

  Future<void> refreshAll() async {
    if (_location == null || !_isValidLocation(_location)) {
      await useDeviceLocation();
    } else {
      await _reloadPrayerAndPlaces();
    }
  }

  Future<void> useDeviceLocation() async {
    _loadingLocation = true;
    _prayerLoadFailed = false;
    _placesLoadFailed = false;
    notifyListeners();
    try {
      final loc = await _locationSearch.fetchGpsLocation();
      if (loc == null || !_isValidLocation(loc)) {
        _queueToast(
          AppErrorMessages.from(
            Exception('location unavailable'),
            context: FinderErrorContext.location,
          ),
        );
        notifyListeners();
        return;
      }
      await _setLocation(loc);
    } catch (e) {
      _queueToast(
        AppErrorMessages.from(e, context: FinderErrorContext.location),
      );
      notifyListeners();
    } finally {
      _loadingLocation = false;
      notifyListeners();
    }
  }

  Future<void> selectSearchResult(LocationSearchResult result) async {
    if (result.latitude.abs() <= 1e-6 && result.longitude.abs() <= 1e-6) {
      _queueToast(
        AppErrorMessages.from(
          Exception('invalid location'),
          context: FinderErrorContext.search,
        ),
      );
      notifyListeners();
      return;
    }

    final detail = await _locationSearch.reverseGeocode(result.latitude, result.longitude);
    final loc = SelectedLocation(
      latitude: result.latitude,
      longitude: result.longitude,
      displayName: detail?.displayName ?? result.displayName,
      locality: detail?.locality,
      country: detail?.country,
    );
    await _setLocation(loc);
  }

  Future<void> _setLocation(SelectedLocation loc) async {
    if (!_isValidLocation(loc)) {
      _queueToast(
        AppErrorMessages.from(
          Exception('invalid location'),
          context: FinderErrorContext.search,
        ),
      );
      notifyListeners();
      return;
    }

    _location = loc;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocation, json.encode(loc.toJson()));
    notifyListeners();
    await _reloadPrayerAndPlaces();
  }

  Future<void> setMadhab(Madhab madhab) async {
    _madhab = madhab;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMadhab, madhab == Madhab.hanafi ? 'hanafi' : 'shafi');
    if (_location != null) await _loadPrayerTimes();
    notifyListeners();
  }

  void setPlaceMode(IslamicFinderPlaceMode mode) {
    if (_placeMode == mode) return;
    _placeMode = mode;
    notifyListeners();
    if (_isValidLocation(_location)) unawaited(_loadPlaces());
  }

  void selectCommitteeMasjid(NearbyPlace masjid) {
    _selectedMasjidId = masjid.id;
    if (_isValidLocation(_location)) unawaited(_loadPrayerTimes());
  }

  Future<void> _reloadPrayerAndPlaces() async {
    if (!_isValidLocation(_location)) return;
    await Future.wait([_loadPrayerTimes(), _loadPlaces()]);
  }

  Future<void> _loadPrayerTimes() async {
    final loc = _location;
    if (!_isValidLocation(loc)) return;
    _loadingPrayer = true;
    _prayerLoadFailed = false;
    notifyListeners();
    try {
      _schedule = await _prayerTimes.loadSchedule(
        location: loc!,
        madhab: _madhab,
        committeeMasjidId: _selectedMasjidId,
      );
    } catch (e) {
      _prayerLoadFailed = true;
      _queueToast(
        AppErrorMessages.from(e, context: FinderErrorContext.prayerTimes),
      );
    }
    _loadingPrayer = false;
    notifyListeners();
  }

  Future<void> _loadPlaces() async {
    final loc = _location;
    if (!_isValidLocation(loc)) return;
    _loadingPlaces = true;
    _placesLoadFailed = false;
    notifyListeners();
    try {
      final type = _placeMode == IslamicFinderPlaceMode.masjid
          ? NearbyPlaceType.masjid
          : NearbyPlaceType.halalFood;
      _places = await _nearbyPlaces.fetchNearby(
        latitude: loc!.latitude,
        longitude: loc.longitude,
        type: type,
      );
      if (_places.isEmpty) {
        _placesLoadFailed = false;
      }
    } catch (e) {
      _places = [];
      _placesLoadFailed = true;
      _queueToast(
        AppErrorMessages.from(e, context: FinderErrorContext.nearbyPlaces),
      );
    }
    _loadingPlaces = false;
    notifyListeners();
  }

  Future<List<LocationSearchResult>> searchLocations(String query) async {
    try {
      return await _locationSearch.searchAddresses(query);
    } catch (e) {
      _queueToast(
        AppErrorMessages.from(e, context: FinderErrorContext.search),
      );
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _locationSearch.dispose();
    super.dispose();
  }
}
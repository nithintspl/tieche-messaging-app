import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class LocalStorageService {
  static const String _keyUser = 'auth_user';
  static const String _keyReadNotifications = 'read_notifications';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  // Initialize service
  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  // User management
  Future<bool> saveUser(User user) async {
    final jsonStr = json.encode(user.toJson());
    return await _prefs.setString(_keyUser, jsonStr);
  }

  User? getUser() {
    final jsonStr = _prefs.getString(_keyUser);
    if (jsonStr == null) return null;
    try {
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      return User.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<bool> clearUser() async {
    return await _prefs.remove(_keyUser);
  }

  // Notifications management
  Future<bool> saveReadNotifications(List<String> readIds) async {
    return await _prefs.setStringList(_keyReadNotifications, readIds);
  }

  List<String> getReadNotifications() {
    return _prefs.getStringList(_keyReadNotifications) ?? [];
  }
}

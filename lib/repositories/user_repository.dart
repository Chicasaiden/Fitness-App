import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../user.dart';

/// Repository for managing user authentication and persistence
class UserRepository {
  static const String _currentUserKey = 'current_user';
  late SharedPreferences _prefs;

  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save current logged-in user
  Future<void> saveCurrentUser(User user) async {
    final userJson = jsonEncode(user.toJson());
    await _prefs.setString(_currentUserKey, userJson);
  }

  /// Get current logged-in user
  User? getCurrentUser() {
    final userJson = _prefs.getString(_currentUserKey);
    if (userJson == null) return null;
    try {
      final decoded = jsonDecode(userJson) as Map<String, dynamic>;
      return User.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    await _prefs.remove(_currentUserKey);
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _prefs.containsKey(_currentUserKey);
  }
}

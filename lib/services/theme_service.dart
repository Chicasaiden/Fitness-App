import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app-wide dark/light mode and persists the choice to disk.
///
/// Usage:
///   ThemeService.of(context).isDark   — read
///   ThemeService.of(context).toggle() — toggle
class ThemeService extends ChangeNotifier {
  static const _key = 'darkMode';

  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
  }

  // ─── Static accessor ───────────────────────────────────────────────────────
  // Allows widgets to call ThemeService.of(context) instead of needing Provider.

  static ThemeService? _instance;
  static ThemeService get instance {
    _instance ??= ThemeService();
    return _instance!;
  }
}

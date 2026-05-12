import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    final raw = _prefs.getString(_key);
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  static const _key = 'themeMode';
  final SharedPreferences _prefs;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    await _prefs.setString(_key, mode.name);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setMode(switch (_mode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    });
  }
}

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user settings: local-time display format and app theme.
///
/// Choices are stored with `shared_preferences` so they survive app restarts.
class SettingsService extends ChangeNotifier {
  static const _kLocalUse24h = 'local_time_use_24h';
  static const _kThemeMode = 'theme_mode';
  static const _kOverlayEnabled = 'overlay_enabled';

  bool _loaded = false;
  bool _localUse24h = false; // default: 12-hour on first launch
  ThemeMode _themeMode = ThemeMode.dark; // default: dark on first launch
  bool _overlayEnabled = false; // floating UTC chip over other apps (Android)

  /// Whether initial load from disk has completed.
  bool get loaded => _loaded;

  /// `true`  -> local time shown as 24-hour `HH:mm:ss`
  /// `false` -> local time shown as 12-hour `hh:mm:ss AM/PM`
  ///
  /// Never affects the UTC display, which is always 24-hour.
  bool get localUse24h => _localUse24h;

  /// System / light / dark. Applied to `MaterialApp.themeMode`.
  ThemeMode get themeMode => _themeMode;

  /// Whether the user wants the floating UTC chip shown over other apps.
  /// The actual overlay/permission state is owned by `UtcOverlayController`.
  bool get overlayEnabled => _overlayEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _localUse24h = prefs.getBool(_kLocalUse24h) ?? false;
    _themeMode = _parseThemeMode(prefs.getString(_kThemeMode));
    _overlayEnabled = prefs.getBool(_kOverlayEnabled) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocalUse24h(bool value) async {
    if (_localUse24h == value) return;
    _localUse24h = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocalUse24h, value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, value.name);
  }

  Future<void> setOverlayEnabled(bool value) async {
    if (_overlayEnabled == value) return;
    _overlayEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOverlayEnabled, value);
  }

  static ThemeMode _parseThemeMode(String? name) => switch (name) {
    'system' => ThemeMode.system,
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.dark, // unset / unrecognised -> default
  };
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user settings. Currently just the local-time display format.
///
/// The choice is stored with `shared_preferences` so it survives app restarts.
class SettingsService extends ChangeNotifier {
  static const _kLocalUse24h = 'local_time_use_24h';

  bool _loaded = false;
  bool _localUse24h = false; // default: 12-hour on first launch

  /// Whether initial load from disk has completed.
  bool get loaded => _loaded;

  /// `true`  -> local time shown as 24-hour `HH:mm:ss`
  /// `false` -> local time shown as 12-hour `hh:mm:ss AM/PM`
  ///
  /// Never affects the UTC display, which is always 24-hour.
  bool get localUse24h => _localUse24h;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _localUse24h = prefs.getBool(_kLocalUse24h) ?? false;
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
}

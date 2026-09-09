import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_utc_clock/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh-install defaults', () async {
    final s = SettingsService();
    await s.load();
    expect(s.loaded, isTrue);
    expect(s.localUse24h, isFalse, reason: 'local time defaults to 12-hour');
    expect(s.themeMode, ThemeMode.dark, reason: 'theme defaults to dark');
    expect(s.overlayEnabled, isFalse);
  });

  test('local 12/24-hour choice survives a restart', () async {
    final first = SettingsService();
    await first.load();
    await first.setLocalUse24h(true);

    final second = SettingsService();
    await second.load();
    expect(second.localUse24h, isTrue);
  });

  test('every theme mode round-trips through storage', () async {
    for (final mode in ThemeMode.values) {
      final writer = SettingsService();
      await writer.load();
      await writer.setThemeMode(mode);

      final reader = SettingsService();
      await reader.load();
      expect(reader.themeMode, mode);
    }
  });

  test('an unrecognised stored theme falls back to dark', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'chartreuse'});
    final s = SettingsService();
    await s.load();
    expect(s.themeMode, ThemeMode.dark);
  });

  test('overlayEnabled persists', () async {
    final first = SettingsService();
    await first.load();
    await first.setOverlayEnabled(true);

    final second = SettingsService();
    await second.load();
    expect(second.overlayEnabled, isTrue);
  });

  test('setters notify once; no-op setters stay quiet', () async {
    final s = SettingsService();
    await s.load();
    var notes = 0;
    s.addListener(() => notes++);

    await s.setLocalUse24h(true);
    await s.setThemeMode(ThemeMode.light);
    await s.setOverlayEnabled(true);
    expect(notes, 3);

    await s.setLocalUse24h(true); // same value
    await s.setThemeMode(ThemeMode.light); // same value
    expect(notes, 3);
  });
}

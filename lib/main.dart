import 'package:flutter/material.dart';

import 'clock_screen.dart';
import 'gps_time_controller.dart';
import 'settings_service.dart';
import 'utc_overlay.dart';
import 'utc_overlay_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GpsUtcClockApp());
}

/// Entry point for the floating UTC chip. flutter_overlay_window starts this in
/// a separate Flutter engine; it must be a top-level function named `overlayMain`
/// in this library.
@pragma('vm:entry-point')
void overlayMain() => runUtcOverlay();

class GpsUtcClockApp extends StatefulWidget {
  const GpsUtcClockApp({super.key});

  @override
  State<GpsUtcClockApp> createState() => _GpsUtcClockAppState();
}

class _GpsUtcClockAppState extends State<GpsUtcClockApp> {
  final SettingsService _settings = SettingsService();
  final GpsTimeController _gps = GpsTimeController();
  late final UtcOverlayController _overlay = UtcOverlayController(
    _gps,
    _settings,
  );

  @override
  void initState() {
    super.initState();
    _settings.load().then((_) => _overlay.syncFromSettings());
  }

  @override
  void dispose() {
    _overlay.dispose();
    _gps.dispose();
    _settings.dispose();
    super.dispose();
  }

  static ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00E5A0),
      brightness: brightness,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'GPS UTC Clock',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: _settings.themeMode,
          home: ClockScreen(settings: _settings, gps: _gps, overlay: _overlay),
        );
      },
    );
  }
}

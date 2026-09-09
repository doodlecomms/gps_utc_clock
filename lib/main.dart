import 'package:flutter/material.dart';

import 'clock_screen.dart';
import 'gps_time_controller.dart';
import 'settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GpsUtcClockApp());
}

class GpsUtcClockApp extends StatefulWidget {
  const GpsUtcClockApp({super.key});

  @override
  State<GpsUtcClockApp> createState() => _GpsUtcClockAppState();
}

class _GpsUtcClockAppState extends State<GpsUtcClockApp> {
  final SettingsService _settings = SettingsService();
  final GpsTimeController _gps = GpsTimeController();

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _gps.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS UTC Clock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5A0),
          brightness: Brightness.dark,
        ),
      ),
      home: ClockScreen(settings: _settings, gps: _gps),
    );
  }
}

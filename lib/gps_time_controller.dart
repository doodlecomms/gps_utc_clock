import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_time_plugin/gps_time_plugin.dart';

/// How long we wait for a fresh GPS fix before giving up.
const Duration kFixTimeout = Duration(seconds: 60);

enum SyncStatus { never, searching, synced, error }

/// Result of a successful GPS time sync, kept in memory only.
@immutable
class GpsSyncInfo {
  const GpsSyncInfo({
    required this.performedAt,
    required this.trustedUtcAtSync,
    required this.offset,
    required this.fixAgeSeconds,
    required this.accuracyMeters,
    required this.source,
  });

  /// Device wall-clock instant the sync completed (used for "x min ago").
  final DateTime performedAt;

  /// Trusted UTC at the moment [performedAt] was captured.
  final DateTime trustedUtcAtSync;

  /// `trustedUtc - deviceUtc`. Add this to `DateTime.now().toUtc()` to get
  /// trusted UTC going forward.
  final Duration offset;

  /// Age of the underlying GPS fix, already compensated for in [offset].
  final int fixAgeSeconds;

  /// Horizontal accuracy of the fix in metres, if known.
  final double? accuracyMeters;

  /// Which mechanism produced [offset] (for display / debugging).
  final String source;
}

/// Owns everything about GPS-derived time:
///   * the currently applied clock [offset]
///   * the sync workflow ([forceGpsFix]) and its [status]
///
/// Time correction is intentionally in-memory only; a restart falls back to the
/// system clock until the next fix.
class GpsTimeController extends ChangeNotifier {
  final GpsTimePlugin _plugin = GpsTimePlugin();
  StreamSubscription<GpsTimeState>? _pluginSub;
  GpsTimeState? _latestPluginState;

  SyncStatus _status = SyncStatus.never;
  String? _error;
  String _searchMessage = 'Searching for satellites…';
  GpsSyncInfo? _sync;

  SyncStatus get status => _status;
  String? get error => _error;
  String get searchMessage => _searchMessage;
  GpsSyncInfo? get lastSync => _sync;
  bool get isSyncing => _status == SyncStatus.searching;
  bool get isSynced => _sync != null;

  /// Correction to add to the system clock. `Duration.zero` until first sync.
  Duration get offset => _sync?.offset ?? Duration.zero;

  /// Best current estimate of true UTC.
  DateTime trustedUtcNow() => DateTime.now().toUtc().add(offset);

  /// Wall-clock time elapsed since the last successful sync, or `null` if never.
  Duration? get timeSinceSync =>
      _sync == null ? null : DateTime.now().difference(_sync!.performedAt);

  /// Drop the GPS correction and go back to the raw system clock.
  void resetToSystemClock() {
    _sync = null;
    _status = SyncStatus.never;
    _error = null;
    notifyListeners();
  }

  /// Request a fresh, high-accuracy GPS fix and use it to (re)compute [offset].
  ///
  /// Explicitly avoids cached / last-known / network-based location:
  ///   * `LocationAccuracy.best`  -> PRIORITY_HIGH_ACCURACY (GNSS)
  ///   * `forceLocationManager: true` -> legacy Android LocationManager, i.e. the
  ///     real GPS provider rather than the fused/network provider.
  Future<void> forceGpsFix() async {
    if (_status == SyncStatus.searching) return;

    _status = SyncStatus.searching;
    _error = null;
    _searchMessage = 'Starting GPS…';
    notifyListeners();

    try {
      await _ensureLocationUsable();

      // Start the fix-age-aware trusted-time stream. On Android this plugin
      // combines the fix's UTC timestamp with SystemClock.elapsedRealtimeNanos()
      // to produce a time that already accounts for how old the fix is.
      await _startPlugin();

      _searchMessage = 'Searching for satellites…';
      notifyListeners();

      // Drive the GNSS hardware and get a hard success/timeout signal.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          forceLocationManager: true,
          timeLimit: kFixTimeout,
        ),
      ).timeout(kFixTimeout);

      final deviceUtcAtFix = DateTime.now().toUtc();

      // Give the plugin a short grace period to emit a trusted time.
      GpsTimeState? st = _latestPluginState;
      for (var i = 0; i < 8 && (st?.trustedTime == null); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        st = _latestPluginState;
      }

      final Duration offset;
      final int fixAge;
      final double? accuracy;
      final String source;

      if (st?.trustedTime != null && st?.deviceTime != null) {
        // Preferred path: fix-age-adjusted time from gps_time_plugin.
        offset = st!.trustedTime!.toUtc().difference(st.deviceTime!.toUtc());
        fixAge = st.ageSeconds ?? 0;
        accuracy = st.accuracy ?? _accuracyOf(position);
        source = 'gps_time_plugin (fix-age adjusted)';
      } else {
        // Fallback: replicate the offset approach with the raw geolocator fix.
        //   offset0 = fixUtcTimestamp - deviceUtcWhenReceived
        // A forced high-accuracy fix is delivered fresh, so its age is normally
        // ~0. If it wasn't, that age shows up as error in offset0, so fold it
        // back out to keep offset an estimate of (trustedUtc - deviceUtc) now.
        final offset0 = position.timestamp.toUtc().difference(deviceUtcAtFix);
        fixAge = deviceUtcAtFix
            .difference(position.timestamp.toUtc())
            .inSeconds;
        offset = offset0 + Duration(seconds: fixAge > 0 ? fixAge : 0);
        accuracy = _accuracyOf(position);
        source = 'geolocator fix timestamp';
      }

      _sync = GpsSyncInfo(
        performedAt: DateTime.now(),
        trustedUtcAtSync: deviceUtcAtFix.add(offset),
        offset: offset,
        fixAgeSeconds: fixAge,
        accuracyMeters: accuracy,
        source: source,
      );
      _status = SyncStatus.synced;
      notifyListeners();
    } on TimeoutException {
      _fail(
        'No GPS fix within ${kFixTimeout.inSeconds} s. Move outdoors with a '
        'clear view of the sky and try again — GPS will not fix indoors.',
      );
    } on _GpsUnusable catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('GPS fix failed: $e');
    } finally {
      await _stopPlugin();
    }
  }

  Future<void> _ensureLocationUsable() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _GpsUnusable(
        'Location is turned off. Enable Location (GPS) in system settings, '
        'then try again.',
      );
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      _searchMessage = 'Requesting location permission…';
      notifyListeners();
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const _GpsUnusable(
        'Location permission denied. This app needs precise location to read '
        'time from GPS satellites.',
      );
    }
    if (perm == LocationPermission.deniedForever) {
      throw const _GpsUnusable(
        'Location permission is permanently denied. Enable it for this app in '
        'the system settings.',
      );
    }
  }

  double? _accuracyOf(Position p) =>
      p.accuracy.isFinite && p.accuracy > 0 ? p.accuracy : null;

  Future<void> _startPlugin() async {
    await _stopPlugin();
    try {
      await _plugin.startListening();
      _pluginSub = _plugin.gpsTimeStream.listen((s) {
        _latestPluginState = s;
        if (_status == SyncStatus.searching &&
            s.statusMessage.isNotEmpty &&
            s.statusMessage != 'Initializing...') {
          _searchMessage = s.statusMessage;
          notifyListeners();
        }
      }, onError: (_) {});
    } catch (_) {
      // Plugin unavailable on this platform/build; the geolocator fallback in
      // forceGpsFix() still works.
    }
  }

  Future<void> _stopPlugin() async {
    await _pluginSub?.cancel();
    _pluginSub = null;
    _latestPluginState = null;
    try {
      await _plugin.stopListening();
    } catch (_) {}
  }

  void _fail(String message) {
    _error = message;
    _status = SyncStatus.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPlugin();
    super.dispose();
  }
}

class _GpsUnusable implements Exception {
  const _GpsUnusable(this.message);
  final String message;
}

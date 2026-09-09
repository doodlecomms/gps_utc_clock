import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'gps_time_controller.dart';
import 'settings_service.dart';
import 'utc_overlay.dart';

/// Owns the floating "trusted UTC" chip: the draw-over-other-apps permission,
/// showing/closing the overlay, and pushing the current GPS offset to the
/// overlay isolate whenever it changes.
///
/// Android-only. On other platforms every method is a no-op and [supported] is
/// false (there is no equivalent to `SYSTEM_ALERT_WINDOW` on iOS).
class UtcOverlayController extends ChangeNotifier {
  UtcOverlayController(this._gps, this._settings) {
    if (supported) {
      _gps.addListener(_pushIfActive);
      _overlaySub = FlutterOverlayWindow.overlayListener.listen(_onMessage);
    }
  }

  final GpsTimeController _gps;
  final SettingsService _settings;
  StreamSubscription<dynamic>? _overlaySub;
  Timer? _rePushTimer;

  bool get supported => !kIsWeb && Platform.isAndroid;

  bool _active = false;
  bool get active => _active;

  String? _error;
  String? get error => _error;

  /// Reconcile the live overlay with the persisted preference. Call once after
  /// settings have loaded. Won't pull the user into system settings on a cold
  /// start — if the preference is on but permission was revoked, it just clears
  /// the preference.
  Future<void> syncFromSettings() async {
    if (!supported) return;
    final alreadyActive = await FlutterOverlayWindow.isActive();
    if (_settings.overlayEnabled && !alreadyActive) {
      await enable(interactive: false);
    } else if (!_settings.overlayEnabled && alreadyActive) {
      await disable();
    } else {
      _active = alreadyActive;
      if (_active) _pushIfActive();
      notifyListeners();
    }
  }

  Future<void> toggle() => _active ? disable() : enable();

  /// [interactive] true means the user just asked for it, so it's OK to open the
  /// system permission screen. false is used on app start / restore.
  Future<void> enable({bool interactive = true}) async {
    if (!supported) return;
    _error = null;

    var granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted && interactive) {
      granted = (await FlutterOverlayWindow.requestPermission()) ?? false;
    }
    if (!granted) {
      _error = interactive
          ? 'Permission to draw over other apps was denied.'
          : 'Overlay is on in settings but the draw-over-other-apps permission '
                'is no longer granted.';
      await _settings.setOverlayEnabled(false);
      _active = false;
      notifyListeners();
      return;
    }

    // `showOverlay` sizes in raw pixels (unlike `resizeOverlay`), so convert.
    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    int px(int dp) => (dp * dpr).round();
    await FlutterOverlayWindow.showOverlay(
      width: px(kOverlayCompactWDp),
      height: px(kOverlayCompactHDp),
      alignment: OverlayAlignment.topLeft,
      flag: OverlayFlag.defaultFlag,
      enableDrag: true,
      positionGravity: PositionGravity.auto,
      startPosition: kOverlayStartPosition,
      overlayTitle: 'GPS UTC Clock',
      overlayContent: 'Trusted UTC is showing over other apps',
    );
    _active = true;
    await _settings.setOverlayEnabled(true);
    notifyListeners();

    // The overlay isolate needs a moment to attach its message listener.
    _pushIfActive();
    Future.delayed(const Duration(milliseconds: 400), _pushIfActive);
    Future.delayed(const Duration(milliseconds: 1200), _pushIfActive);

    // The overlay engine can be restarted by the OS and comes back with default
    // state; a slow heartbeat re-seeds it without needing a GPS change.
    _rePushTimer?.cancel();
    _rePushTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pushIfActive(),
    );
  }

  Future<void> disable() async {
    if (!supported) return;
    _rePushTimer?.cancel();
    _rePushTimer = null;
    await FlutterOverlayWindow.closeOverlay();
    _active = false;
    _error = null;
    await _settings.setOverlayEnabled(false);
    notifyListeners();
  }

  void _pushIfActive() {
    if (!_active) return;
    FlutterOverlayWindow.shareData({
      'offsetMs': _gps.offset.inMilliseconds,
      'synced': _gps.isSynced,
      'syncedAtMs': _gps.lastSync?.performedAt.millisecondsSinceEpoch,
    });
  }

  void _onMessage(dynamic event) {
    // Note: on the tested devices the overlay->app direction of shareData does
    // not deliver, so this is best-effort. app->overlay (the heartbeat) is what
    // keeps the chip fed; the Settings toggle is the reliable off switch.
    if (event is! Map) return;
    if (event['action'] == 'request') _pushIfActive();
  }

  @override
  void dispose() {
    if (supported) {
      _rePushTimer?.cancel();
      _gps.removeListener(_pushIfActive);
      _overlaySub?.cancel();
    }
    super.dispose();
  }
}

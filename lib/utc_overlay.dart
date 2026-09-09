import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'time_format.dart';

/// Compact / expanded sizes for the floating chip, in **dp**. Kept here so the
/// controller (which calls `showOverlay`) and the widget (which calls
/// `resizeOverlay`) agree. `showOverlay` wants pixels, `resizeOverlay` wants dp.
const int kOverlayCompactWDp = 188;
const int kOverlayCompactHDp = 56;
const int kOverlayExpandedWDp = 240;
const int kOverlayExpandedHDp = 176;

/// Where the chip first appears (dp from the top-left). Below the status bar.
const OverlayPosition kOverlayStartPosition = OverlayPosition(8, 54);

/// Runs the floating UTC chip. Invoked from `overlayMain()` in main.dart, which
/// is the entry point flutter_overlay_window starts in a separate engine.
///
/// This isolate has no access to the app's GPS state, so it receives the current
/// clock offset from the main app via [FlutterOverlayWindow.shareData] and ticks
/// locally once per second.
void runUtcOverlay() {
  WidgetsFlutterBinding.ensureInitialized();
  // No MaterialApp here on purpose: in the overlay engine its async Localizations
  // resolution leaves Text painted with the debug "yellow underline" fallback.
  // The chip only needs Directionality + MediaQuery.
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData.fromView(
          WidgetsBinding.instance.platformDispatcher.views.first,
        ),
        child: const _UtcChip(),
      ),
    ),
  );
}

class _UtcChip extends StatefulWidget {
  const _UtcChip();

  @override
  State<_UtcChip> createState() => _UtcChipState();
}

class _UtcChipState extends State<_UtcChip> {
  static const _mint = Color(0xFF00E5A0);
  static const _amber = Color(0xFFFFB300);

  Timer? _ticker;
  StreamSubscription<dynamic>? _sub;

  Duration _offset = Duration.zero;
  bool _synced = false;
  DateTime? _syncedAt;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Normalise the window to the compact size in density-correct dp
      // (`showOverlay` sizes in raw pixels; `resizeOverlay` converts from dp).
      FlutterOverlayWindow.resizeOverlay(
        kOverlayCompactWDp,
        kOverlayCompactHDp,
        true,
      );
      // Ask the main app to (re)send the current offset — this engine may have
      // just been restarted by the OS with default state.
      FlutterOverlayWindow.shareData({'action': 'request'});
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _sub = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && mounted) {
        setState(() {
          _offset = Duration(
            milliseconds: (event['offsetMs'] as num?)?.toInt() ?? 0,
          );
          _synced = event['synced'] == true;
          final ms = (event['syncedAtMs'] as num?)?.toInt();
          _syncedAt = ms == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(ms);
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  DateTime get _utcNow => DateTime.now().toUtc().add(_offset);

  Future<void> _toggleExpanded() async {
    setState(() => _expanded = !_expanded);
    await FlutterOverlayWindow.resizeOverlay(
      _expanded ? kOverlayExpandedWDp : kOverlayCompactWDp,
      _expanded ? kOverlayExpandedHDp : kOverlayCompactHDp,
      true,
    );
  }

  /// The overlay engine can't call `closeOverlay()` (main-engine only), so it
  /// asks the app to do it. If that message doesn't get through, the Settings
  /// toggle is always a reliable way to turn the chip off.
  Future<void> _close() =>
      FlutterOverlayWindow.shareData({'action': 'disable'});

  Widget _miniButton(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.white70),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final accent = _synced ? _mint : _amber;
    return Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
        onTap: _toggleExpanded,
        onLongPress: _close,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF20B0F0E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatTime24(_utcNow),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'UTC',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 6),
                Text(
                  formatDateIso(_utcNow),
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  _synced
                      ? 'GPS-synced · ${_syncedAt == null ? 'now' : formatAgo(DateTime.now().difference(_syncedAt!))}'
                      : 'System clock · not GPS-verified',
                  style: TextStyle(fontSize: 11, color: accent),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _miniButton('Collapse', _toggleExpanded),
                    const SizedBox(width: 8),
                    _miniButton('Close', _close),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'or turn off in the app Settings',
                  style: TextStyle(fontSize: 9, color: Colors.white38),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

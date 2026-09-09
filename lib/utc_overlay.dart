import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'time_format.dart';

/// Compact / expanded sizes for the floating chip, in **dp**. Shared with the
/// controller, which sizes the initial `showOverlay` window (in pixels).
const int kOverlayCompactWDp = 190;
const int kOverlayCompactHDp = 58;
const int kOverlayExpandedWDp = 244;
const int kOverlayExpandedHDp = 176;

/// Where the chip first appears (dp from the top-left). Below the status bar.
const OverlayPosition kOverlayStartPosition = OverlayPosition(8, 54);

/// Runs the floating UTC chip. Invoked from `overlayMain()` in main.dart, the
/// entry point flutter_overlay_window starts in a separate engine.
///
/// This isolate has no access to the app's GPS state, so it receives the current
/// clock offset from the main app via [FlutterOverlayWindow.shareData] and ticks
/// locally once per second.
void runUtcOverlay() {
  WidgetsFlutterBinding.ensureInitialized();
  // No MaterialApp here on purpose: in the overlay engine its async Localizations
  // resolution leaves Text painted with the debug "yellow underline" fallback.
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
      _resize(kOverlayCompactWDp, kOverlayCompactHDp);
      // Ask the app to (re)send current state — this engine may have just been
      // restarted by the OS with defaults. (A 5s heartbeat in the app backs this.)
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

  Future<void> _resize(int wDp, int hDp) async {
    // The overlay engine may not have registered its method channel yet right
    // after start, so retry a few times.
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        await FlutterOverlayWindow.resizeOverlay(wDp, hDp, true);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    _resize(
      _expanded ? kOverlayExpandedWDp : kOverlayCompactWDp,
      _expanded ? kOverlayExpandedHDp : kOverlayCompactHDp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _synced ? _mint : _amber;

    final timeRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
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
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            _expanded ? 'UTC ▲' : 'UTC ▾',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );

    return Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
        // Tap anywhere on the chip toggles expand/collapse. (The overlay engine
        // can't close its own window, so there's no close button — use the
        // Settings toggle in the app.)
        onTap: _toggleExpanded,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xF20B0F0E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                timeRow,
                if (_expanded) ...[
                  const SizedBox(height: 6),
                  Text(
                    formatDateIso(_utcNow),
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _synced
                        ? 'GPS-synced · ${_syncedAt == null ? 'now' : formatAgo(DateTime.now().difference(_syncedAt!))}'
                        : 'System clock · not GPS-verified',
                    style: TextStyle(fontSize: 11, color: accent),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'tap to collapse · turn off in app Settings',
                    style: TextStyle(fontSize: 9, color: Colors.white38),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

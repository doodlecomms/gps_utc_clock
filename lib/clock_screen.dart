import 'dart:async';

import 'package:flutter/material.dart';

import 'gps_time_controller.dart';
import 'settings_service.dart';
import 'time_format.dart';
import 'utc_overlay_controller.dart';

/// The whole app is this one screen. A gear icon opens a settings bottom sheet.
class ClockScreen extends StatefulWidget {
  const ClockScreen({
    super.key,
    required this.settings,
    required this.gps,
    required this.overlay,
  });

  final SettingsService settings;
  final GpsTimeController gps;
  final UtcOverlayController overlay;

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // One repaint per second keeps both clocks and the "last sync" label live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(
        settings: widget.settings,
        gps: widget.gps,
        overlay: widget.overlay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever settings or GPS state change (in addition to the ticker).
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.settings,
        widget.gps,
        widget.overlay,
      ]),
      builder: (context, _) {
        final gps = widget.gps;
        final nowUtc = gps.trustedUtcNow();
        final nowLocal = nowUtc.toLocal();

        return Scaffold(
          appBar: AppBar(
            title: const Text('GPS UTC Clock'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: _openSettings,
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > constraints.maxHeight;
                  // Landscape: same size for both, side by side. Portrait: UTC
                  // emphasised larger, stacked.
                  final utc = _ClockBlock(
                    label: 'UTC',
                    time: formatTime24(nowUtc),
                    caption: formatDateIso(nowUtc),
                    emphasize: true,
                    digitSize: wide ? 46 : 68,
                  );
                  final local = _ClockBlock(
                    label: 'LOCAL',
                    time: widget.settings.localUse24h
                        ? formatTime24(nowLocal)
                        : formatTime12(nowLocal),
                    caption:
                        '${formatDateIso(nowLocal)}  ·  ${widget.settings.localUse24h ? '24-hour' : '12-hour'}',
                    emphasize: false,
                    digitSize: wide ? 46 : 44,
                  );

                  final clocks = wide
                      ? Row(
                          children: [
                            Expanded(child: Center(child: utc)),
                            Expanded(child: Center(child: local)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [utc, const SizedBox(height: 36), local],
                        );

                  // Fill the viewport normally; scroll if it's too short to fit
                  // (small landscape / split-screen).
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TimeSourceBanner(gps: gps),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 140,
                                ),
                                child: clocks,
                              ),
                            ),
                            _SyncPanel(gps: gps),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: gps.isSyncing ? null : gps.forceGpsFix,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              icon: gps.isSyncing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(Icons.satellite_alt),
                              label: Text(
                                gps.isSyncing ? 'Searching…' : 'Force GPS Fix',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Large, legible, monospaced digits for one clock.
class _ClockBlock extends StatelessWidget {
  const _ClockBlock({
    required this.label,
    required this.time,
    required this.caption,
    required this.emphasize,
    required this.digitSize,
  });

  final String label;
  final String time;
  final String caption;
  final bool emphasize;
  final double digitSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
            color: emphasize ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        // scaleDown keeps the digits on one line if the column is narrow.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            time,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              fontSize: digitSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TimeSourceBanner extends StatelessWidget {
  const _TimeSourceBanner({required this.gps});
  final GpsTimeController gps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final synced = gps.isSynced;
    final text = synced
        ? 'GPS-corrected  (${formatOffset(gps.offset)} vs system clock)'
        : 'System clock  (not GPS-verified)';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: synced
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            synced ? Icons.gps_fixed : Icons.gps_off,
            size: 16,
            color: synced ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: synced
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncPanel extends StatelessWidget {
  const _SyncPanel({required this.gps});
  final GpsTimeController gps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sync = gps.lastSync;

    final String lastSyncLabel;
    if (sync == null) {
      lastSyncLabel = 'Last GPS sync: Never';
    } else {
      lastSyncLabel =
          'Last GPS sync: ${formatAgo(gps.timeSinceSync ?? Duration.zero)}';
    }

    final children = <Widget>[
      Row(
        children: [
          Icon(Icons.history, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            lastSyncLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ];

    if (gps.status == SyncStatus.searching) {
      children.add(const SizedBox(height: 8));
      children.add(
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                gps.searchMessage,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 24),
          child: Text(
            'Can take 30+ seconds outdoors. Will not fix indoors.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    } else if (gps.status == SyncStatus.error) {
      children.add(const SizedBox(height: 8));
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 16, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                gps.error ?? 'GPS fix failed.',
                style: TextStyle(color: scheme.error),
              ),
            ),
          ],
        ),
      );
    } else if (sync != null) {
      children.add(const SizedBox(height: 6));
      children.add(
        Text(
          _detailLine(sync),
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  String _detailLine(GpsSyncInfo s) {
    final parts = <String>[
      'offset ${formatOffset(s.offset)}',
      'fix age ${s.fixAgeSeconds}s',
      if (s.accuracyMeters != null)
        'acc ±${s.accuracyMeters!.toStringAsFixed(0)} m',
      s.source,
    ];
    return parts.join('  ·  ');
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.settings,
    required this.gps,
    required this.overlay,
  });

  final SettingsService settings;
  final GpsTimeController gps;
  final UtcOverlayController overlay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([settings, gps, overlay]),
      builder: (context, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Local time: 24-hour'),
                  subtitle: Text(
                    settings.localUse24h
                        ? 'Showing HH:mm:ss'
                        : 'Showing hh:mm:ss AM/PM',
                  ),
                  value: settings.localUse24h,
                  onChanged: settings.setLocalUse24h,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'UTC is always shown in 24-hour format and is never affected '
                    'by this toggle.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const Divider(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Appearance',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                ),
                if (overlay.supported) ...[
                  const Divider(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Floating UTC chip'),
                    subtitle: Text(
                      overlay.error ??
                          (overlay.active
                              ? 'Showing over other apps. Tap it to expand; '
                                    'toggle off here to hide it.'
                              : 'Show trusted UTC on top of other apps '
                                    '(e.g. JS8Call).'),
                      style: overlay.error != null
                          ? TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                    ),
                    isThreeLine: true,
                    value: overlay.active,
                    onChanged: (_) => overlay.toggle(),
                  ),
                ],
                if (gps.isSynced) ...[
                  const Divider(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      gps.resetToSystemClock();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset to system clock'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

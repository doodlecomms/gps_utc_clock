/// Hand-rolled time formatters.
///
/// These deliberately do **not** use `intl` / `DateFormat` or any locale-aware
/// formatter, so the output can never inherit the device's 12/24-hour system
/// setting. The caller decides the format explicitly.
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// 24-hour clock, always `HH:mm:ss`. Used for UTC, which is never affected by
/// the in-app local-time toggle.
String formatTime24(DateTime t) =>
    '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

/// 12-hour clock, always `hh:mm:ss AM/PM`.
String formatTime12(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final meridiem = t.hour < 12 ? 'AM' : 'PM';
  return '${_two(h12)}:${_two(t.minute)}:${_two(t.second)} $meridiem';
}

/// `YYYY-MM-DD` (ISO-style, locale-independent).
String formatDateIso(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';

/// Human-readable "time ago" for the last-sync label.
String formatAgo(Duration d) {
  if (d.isNegative) return 'just now';
  final s = d.inSeconds;
  if (s < 10) return 'just now';
  if (s < 60) return '$s sec ago';
  final m = d.inMinutes;
  if (m < 60) return '$m min ago';
  final h = d.inHours;
  if (h < 24) return '$h hr ${m - h * 60} min ago';
  final days = d.inDays;
  return '$days day${days == 1 ? '' : 's'} ago';
}

/// Signed millisecond offset rendered compactly, e.g. `+0.42 s`, `-1.90 s`.
String formatOffset(Duration offset) {
  final ms = offset.inMilliseconds;
  final sign = ms >= 0 ? '+' : '-';
  final abs = ms.abs();
  if (abs < 1000) return '$sign$abs ms';
  return '$sign${(abs / 1000).toStringAsFixed(2)} s';
}

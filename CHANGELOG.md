# Changelog

## 1.2.0

- **Landscape** genuinely works now — UTC and LOCAL side by side, sync panel and
  the Force GPS Fix button in a row, nothing clipped. (1.1.0's attempt still
  overflowed.) Short viewports scroll.
- **Fixed the geolocator-only fallback offset.** It used to fold a measured
  "fix age" back into the correction, which cancelled out exactly the
  system-clock error it was meant to show. It now just trusts the fresh fix
  timestamp. The `gps_time_plugin` path (the normal case) was already correct.
- The offset calculations are extracted as pure functions with unit tests
  (`test/gps_offset_test.dart`, `test/settings_service_test.dart`).

## 1.1.0

- **Floating UTC chip (Android)** — an always-on-top pill showing GPS-corrected
  UTC over any other app (e.g. JS8Call). Amber = system clock, green =
  GPS-synced; tap to expand, drag to move. Enable/disable in Settings; first use
  sends you to Android's "Appear on top" permission screen.
- **Appearance: System / Light / Dark** toggle in Settings, persisted. Defaults
  to Dark.
- First pass at a landscape layout (still had overflow issues — see 1.2.0).
- App display name is now "GPS UTC Clock".

## 1.0.2

- Real launcher icon (clock + reticle + satellite + GPS pin) on Android and iOS.
- `releases/latest/download/gps-utc-clock.apk` permalink always points at the
  newest build.

## 1.0.0

- Initial release: live UTC (always 24-hour) and local time, in-app 12/24-hour
  toggle, Force GPS Fix with fix-age-adjusted trusted time via `gps_time_plugin`,
  live "last GPS sync" label.

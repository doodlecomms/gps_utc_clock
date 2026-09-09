# Changelog

## 1.1.0

- **Floating UTC chip (Android)** — an always-on-top pill showing GPS-corrected
  UTC over any other app (e.g. JS8Call). Amber = system clock, green =
  GPS-synced; tap to expand, drag to move. Enable/disable in Settings; first use
  sends you to Android's "Appear on top" permission screen.
- **Appearance: System / Light / Dark** toggle in Settings, persisted. Defaults
  to Dark.
- **Landscape support** — the two clocks lay out side by side; short viewports
  (split-screen) now scroll instead of overflowing.
- App display name is now "GPS UTC Clock".

## 1.0.2

- Real launcher icon (clock + reticle + satellite + GPS pin) on Android and iOS.
- `releases/latest/download/gps-utc-clock.apk` permalink always points at the
  newest build.

## 1.0.0

- Initial release: live UTC (always 24-hour) and local time, in-app 12/24-hour
  toggle, Force GPS Fix with fix-age-adjusted trusted time via `gps_time_plugin`,
  live "last GPS sync" label.

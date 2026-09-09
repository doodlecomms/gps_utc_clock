import 'package:flutter_test/flutter_test.dart';

import 'package:gps_utc_clock/gps_time_controller.dart';

void main() {
  group('gpsOffsetFromTrustedTime', () {
    test('offset = trustedUtc - deviceUtc', () {
      final trusted = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final device = DateTime.utc(2026, 1, 1, 12, 0, 1, 850); // 1.85 s fast
      expect(
        gpsOffsetFromTrustedTime(trustedUtc: trusted, deviceUtc: device),
        const Duration(milliseconds: -1850),
      );
    });

    test('slow device clock yields a positive correction', () {
      final trusted = DateTime.utc(2026, 1, 1, 12, 0, 3);
      final device = DateTime.utc(2026, 1, 1, 12, 0, 0);
      expect(
        gpsOffsetFromTrustedTime(trustedUtc: trusted, deviceUtc: device),
        const Duration(seconds: 3),
      );
    });
  });

  group('gpsOffsetFromRawFix', () {
    test('fresh fix + fast clock -> negative correction (was the old bug)', () {
      // Device reads 12:00:05 when true time is 12:00:00; fix taken "now".
      final fixUtc = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final deviceAtReceipt = DateTime.utc(2026, 1, 1, 12, 0, 5);
      expect(
        gpsOffsetFromRawFix(
          fixUtc: fixUtc,
          deviceUtcAtReceipt: deviceAtReceipt,
        ),
        const Duration(seconds: -5),
      );
    });

    test('fresh fix + slow clock -> positive correction', () {
      final fixUtc = DateTime.utc(2026, 1, 1, 12, 0, 3);
      final deviceAtReceipt = DateTime.utc(2026, 1, 1, 12, 0, 0);
      expect(
        gpsOffsetFromRawFix(
          fixUtc: fixUtc,
          deviceUtcAtReceipt: deviceAtReceipt,
        ),
        const Duration(seconds: 3),
      );
    });

    test('sub-second offset is preserved', () {
      final fixUtc = DateTime.utc(2026, 1, 1, 12, 0, 0, 0);
      final deviceAtReceipt = DateTime.utc(2026, 1, 1, 12, 0, 0, 420);
      expect(
        gpsOffsetFromRawFix(
          fixUtc: fixUtc,
          deviceUtcAtReceipt: deviceAtReceipt,
        ),
        const Duration(milliseconds: -420),
      );
    });

    test('non-UTC inputs are normalised before differencing', () {
      final localFix = DateTime(2026, 1, 1, 12, 0, 0); // device local zone
      expect(
        gpsOffsetFromRawFix(
          fixUtc: localFix,
          deviceUtcAtReceipt: localFix.add(const Duration(milliseconds: 200)),
        ),
        const Duration(milliseconds: -200),
      );
    });
  });
}

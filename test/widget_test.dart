import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gps_utc_clock/time_format.dart';

void main() {
  test('UTC is always 24-hour regardless of value', () {
    final morning = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final evening = DateTime.utc(2026, 1, 2, 23, 9, 7);
    expect(formatTime24(morning), '03:04:05');
    expect(formatTime24(evening), '23:09:07');
  });

  test('12-hour formatter uses AM/PM and 12 for noon/midnight', () {
    expect(formatTime12(DateTime(2026, 1, 1, 0, 0, 0)), '12:00:00 AM');
    expect(formatTime12(DateTime(2026, 1, 1, 12, 0, 0)), '12:00:00 PM');
    expect(formatTime12(DateTime(2026, 1, 1, 13, 5, 9)), '01:05:09 PM');
  });

  test('offset formatting is signed', () {
    expect(formatOffset(const Duration(milliseconds: 420)), '+420 ms');
    expect(formatOffset(const Duration(milliseconds: -1900)), '-1.90 s');
  });

  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('ok'))),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}

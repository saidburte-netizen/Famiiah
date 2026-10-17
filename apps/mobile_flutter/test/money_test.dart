import 'package:fam_mobile/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMoney', () {
    test('formats a numeric string', () {
      expect(formatMoney('1234.5'), 'ETB 1,234.50');
    });

    test('formats a double', () {
      expect(formatMoney(1000), 'ETB 1,000.00');
    });

    test('treats null as zero', () {
      expect(formatMoney(null), 'ETB 0.00');
    });

    test('strips grouping separators from input', () {
      expect(formatMoney('1,250.75'), 'ETB 1,250.75');
    });

    test('honours a non-default currency', () {
      expect(formatMoney('10', currency: 'USD'), 'USD 10.00');
    });

    test('falls back to zero on garbage input', () {
      expect(formatMoney('not-a-number'), 'ETB 0.00');
    });
  });
}

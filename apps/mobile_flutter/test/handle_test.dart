import 'package:fam_mobile/core/handle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeHandle', () {
    test('normalises what people actually type', () {
      expect(normalizeHandle('@Abebe'), 'abebe');
      expect(normalizeHandle('  Abebe  '), 'abebe');
      expect(normalizeHandle('@@abebe'), 'abebe');
      expect(normalizeHandle('abe_be1'), 'abe_be1');
      expect(normalizeHandle('a1b2c3'), 'a1b2c3');
    });

    test('rejects anything the database would reject', () {
      for (final bad in ['', '   ', 'ab', '1abe', 'ab-cd', 'ab cd', 'abe.be', 'a' * 25, '@', null]) {
        expect(normalizeHandle(bad), isNull, reason: '$bad');
      }
    });
  });
}

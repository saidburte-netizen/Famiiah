import 'package:fam_mobile/core/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toE164', () {
    test('normalises the shapes people actually type', () {
      expect(toE164('0912345678'), '+251912345678');
      expect(toE164('+251912345678'), '+251912345678');
      expect(toE164('251912345678'), '+251912345678');
      expect(toE164('912345678'), '+251912345678');
      expect(toE164('09 12 34 56 78'), '+251912345678');
      expect(toE164('+251 91 234 5678'), '+251912345678');
      expect(toE164('(0912) 345-678'), '+251912345678');
      expect(toE164('+251712345678'), '+251712345678');
    });

    test('rejects anything that is not an Ethiopian mobile number', () {
      for (final bad in ['', '  ', '12345', '0812345678', '+14155552671', '091234567', '09123456789', 'abc']) {
        expect(toE164(bad), isNull, reason: bad);
      }
    });
  });

  group('looksLikeEmail', () {
    test('separates email identifiers from phone numbers', () {
      expect(looksLikeEmail('owner@fam.et'), isTrue);
      expect(looksLikeEmail('0912345678'), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/utils/formatters.dart';

void main() {
  group('yearLabel', () {
    test('is a bare Gregorian year when useEthiopian is false', () {
      expect(yearLabel(DateTime(2026, 1, 1), useEthiopian: false), '2026');
      expect(yearLabel(DateTime(2026, 12, 31), useEthiopian: false), '2026');
    });

    test('matches toEthiopianDate for the same date when useEthiopian is true', () {
      final date = DateTime(2026, 3, 15);
      expect(yearLabel(date, useEthiopian: true), '${toEthiopianDate(date).year} E.C.');
    });

    test('crosses the Ethiopian new year around September 11, per the app\'s own '
        'verified reference date (Meskerem 1, 2017 E.C. = September 11, 2024)', () {
      expect(yearLabel(DateTime(2024, 9, 11), useEthiopian: true), '2017 E.C.');
      expect(yearLabel(DateTime(2024, 9, 10), useEthiopian: true), '2016 E.C.');
    });

    test('a Gregorian Jan 1 falls in the Ethiopian year that started the previous September',
        () {
      // Sanity check on the mapping direction, not just internal
      // self-consistency: Jan 1 of a Gregorian year is always a few months
      // into the Ethiopian year that began the preceding September.
      final janFirst = DateTime(2026, 1, 1);
      final precedingSeptember = DateTime(2025, 9, 15);
      expect(
        yearLabel(janFirst, useEthiopian: true),
        yearLabel(precedingSeptember, useEthiopian: true),
      );
    });
  });
}

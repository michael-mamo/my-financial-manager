import 'package:intl/intl.dart';

/// Formats an amount with the given currency code, e.g. `formatMoney(45500, 'ETB')`
/// -> "45,500 ETB" (spec examples consistently put the code after the number).
String formatMoney(double amount, String currencyCode, {String locale = 'en'}) {
  final formatter = NumberFormat.decimalPattern(locale);
  return '${formatter.format(amount)} $currencyCode';
}

String formatDate(DateTime date, {String locale = 'en'}) {
  return DateFormat('dd/MM/yyyy', locale).format(date);
}

/// Addendum #10: Ethiopian-calendar *display* toggle. Storage stays
/// Gregorian everywhere (DB, date pickers, exports) — this only changes
/// how a date is shown to the person, computed on the fly from the stored
/// Gregorian date.
class EthiopianDate {
  final int year;
  final int month; // 1-13 (13th month, Pagume, has 5 or 6 days)
  final int day;
  const EthiopianDate(this.year, this.month, this.day);
}

const _ethiopianMonthsEn = [
  'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit', 'Megabit',
  'Miyazya', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume',
];
const _ethiopianMonthsAm = [
  'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሳስ', 'ጥር', 'የካቲት', 'መጋቢት',
  'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ',
];

// Standard Julian Day Number epoch for the Ethiopian calendar (Meskerem 1,
// year 1 E.C. = August 29, 8 CE Julian). This constant and the conversion
// below follow the well-established public-domain JDN calendar-conversion
// method used across Ethiopian calendar tools generally.
const _ethiopicEpochJdn = 1724221;

int _gregorianToJdn(DateTime date) {
  final a = (14 - date.month) ~/ 12;
  final y = date.year + 4800 - a;
  final m = date.month + 12 * a - 3;
  return date.day +
      ((153 * m + 2) ~/ 5) +
      365 * y +
      (y ~/ 4) -
      (y ~/ 100) +
      (y ~/ 400) -
      32045;
}

EthiopianDate toEthiopianDate(DateTime date) {
  final n = _gregorianToJdn(date) - _ethiopicEpochJdn;
  final eraYear = n ~/ 1461; // 1461 days = one 4-year Ethiopian leap cycle
  final dayInEra = n % 1461;
  int yearInEra;
  int dayOfYear;
  if (dayInEra < 1095) {
    yearInEra = dayInEra ~/ 365;
    dayOfYear = dayInEra % 365;
  } else {
    yearInEra = 3; // the leap year of the cycle (366 days)
    dayOfYear = dayInEra - 1095;
  }
  return EthiopianDate(
    eraYear * 4 + yearInEra + 1,
    dayOfYear ~/ 30 + 1,
    dayOfYear % 30 + 1,
  );
}

String formatDateEthiopian(DateTime date, {String languageCode = 'en'}) {
  final e = toEthiopianDate(date);
  final months = languageCode == 'am' ? _ethiopianMonthsAm : _ethiopianMonthsEn;
  return '${e.day} ${months[e.month - 1]} ${e.year}';
}

/// The single call site UI code should use for any user-facing date: honors
/// the Ethiopian-calendar toggle when [useEthiopian] is true, otherwise
/// falls back to the standard Gregorian format.
String formatDateDisplay(DateTime date, {required bool useEthiopian, String locale = 'en'}) {
  return useEthiopian ? formatDateEthiopian(date, languageCode: locale) : formatDate(date, locale: locale);
}

/// A bare year, honoring the same Ethiopian-calendar toggle as
/// [formatDateDisplay] — for spots that show only a year rather than a
/// full date (the Reports "Year" range label, the PDF export footer).
/// Storage and the underlying period boundaries stay Gregorian either way
/// (Addendum #10); this only converts what's shown. [date] should be a
/// day that actually falls within the year being labeled (e.g. its first
/// day) — the Ethiopian year for a given Gregorian year isn't a fixed
/// offset, since the Ethiopian new year lands in September.
String yearLabel(DateTime date, {required bool useEthiopian}) {
  return useEthiopian ? '${toEthiopianDate(date).year} E.C.' : '${date.year}';
}

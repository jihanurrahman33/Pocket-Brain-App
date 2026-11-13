import '../../../core/utils/clock.dart';

/// Parses everyday date expressions such as "December 15", "15 Dec",
/// "2026-12-15", "tomorrow" or "next week". Dates already past this year
/// roll over to next year.
final class DateExpressionParser {
  const DateExpressionParser();

  static const _months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  static const _monthAlternation = 'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec';
  static final _iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
  static final _monthFirst = RegExp('\\b($_monthAlternation)[a-z]*\\.?\\s+(\\d{1,2})');
  static final _dayFirst = RegExp('\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+($_monthAlternation)');
  static const _maxDay = 31;
  static const _daysInWeek = 7;

  DateTime? parse(String text, {required DateTime now}) {
    final lower = text.toLowerCase();
    final today = now.startOfDay;
    if (lower.contains('tomorrow')) return today.add(const Duration(days: 1));
    if (lower.contains('today') || lower.contains('tonight')) return today;
    if (lower.contains('next week')) return today.add(const Duration(days: _daysInWeek));

    if (_iso.firstMatch(lower) case final m?) {
      return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    }
    final (month, day) = switch ((_monthFirst.firstMatch(lower), _dayFirst.firstMatch(lower))) {
      (final m?, _) => (_months.indexOf(m[1]!) + 1, int.parse(m[2]!)),
      (null, final m?) => (_months.indexOf(m[2]!) + 1, int.parse(m[1]!)),
      _ => (0, 0),
    };
    if (month == 0 || day < 1 || day > _maxDay) return null;
    final date = DateTime(now.year, month, day);
    return date.isBefore(today) ? DateTime(now.year + 1, month, day) : date;
  }
}

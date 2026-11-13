/// Finds the day a plan is for in the user's own words ("tomorrow", "on
/// Friday", "next monday", Banglish "kal"), deterministically. Returns a
/// date at midnight, or null when no day is named.
abstract final class DueDateParser {
  static const _weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static final _dayAfterTomorrow = RegExp(
    r'\b(day after tomorrow|porshu|porshudin)\b',
    caseSensitive: false,
  );
  static final _tomorrow = RegExp(r'\b(tomorrow|tmrw|tmr|kal|agamikal)\b', caseSensitive: false);
  static final _today = RegExp(
    r'\b(today|tonight|this (morning|afternoon|evening)|aj|aaj)\b',
    caseSensitive: false,
  );
  static final _weekday = RegExp(
    r'\b(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    caseSensitive: false,
  );

  /// Every phrase [parse] understands, so callers can remove it from a title.
  static final phrase = RegExp(
    r'\b(?:(?:on|by|this|next)\s+)?(?:day after tomorrow|tomorrow|tmrw|tmr|today|tonight|'
    r'this (?:morning|afternoon|evening)|agamikal|porshu|'
    r'monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    caseSensitive: false,
  );

  static DateTime? parse(String text, {required DateTime now}) {
    final today = DateTime(now.year, now.month, now.day);
    if (_dayAfterTomorrow.hasMatch(text)) return _add(today, 2);
    if (_tomorrow.hasMatch(text)) return _add(today, 1);
    if (_today.hasMatch(text)) return today;
    if (_weekday.firstMatch(text) case final m?) {
      final target = _weekdays.indexOf(m[2]!.toLowerCase()) + 1;
      var days = (target - now.weekday) % 7;
      // The coming one ("next Friday" too); on a Friday, "Friday" is next week.
      if (days == 0) days = 7;
      return _add(today, days);
    }
    return null;
  }

  static DateTime _add(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);
}

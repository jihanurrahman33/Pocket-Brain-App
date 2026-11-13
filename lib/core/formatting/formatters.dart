import 'package:intl/intl.dart';

import '../utils/clock.dart';

/// Presentation formatting helpers.
abstract final class Formatters {
  static const _daysInWeek = 7;

  /// "Today, 9:41 PM", "Yesterday", "Monday", "Nov 3" or "Nov 3, 2024".
  static String friendlyDate(DateTime date, {DateTime? now}) {
    final today = (now ?? DateTime.now()).startOfDay;
    final days = today.difference(date.startOfDay).inDays;
    if (days == 0) return 'Today, ${DateFormat.jm().format(date)}';
    if (days == 1) return 'Yesterday';
    if (days > 1 && days < _daysInWeek) return DateFormat.EEEE().format(date);
    if (date.year == today.year) return DateFormat.MMMd().format(date);
    return DateFormat.yMMMd().format(date);
  }

  static String fullDateTime(DateTime date) => DateFormat.yMMMMd().add_jm().format(date);

  static String shortDateTime(DateTime date) => DateFormat.MMMd().add_jm().format(date);

  static String bytes(int bytes) {
    const kb = 1 << 10, mb = 1 << 20, gb = 1 << 30;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(0)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  static String plural(int count, String singular, [String? plural]) =>
      '$count ${count == 1 ? singular : plural ?? '${singular}s'}';
}

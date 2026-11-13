/// Abstraction over the current time so date-based rules are testable.
abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Date helpers that do not depend on any clock.
extension DateOnly on DateTime {
  /// Midnight at the start of this day.
  DateTime get startOfDay => DateTime(year, month, day);

  bool isSameDay(DateTime other) => year == other.year && month == other.month && day == other.day;
}

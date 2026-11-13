/// Finds when to remind from the user's own words, deterministically.
///
/// Small models are unreliable at time arithmetic, so phrases like "in 5
/// minutes", "after 2 hours", "5 minute pore", "at 6 pm" or "at 18:30" are
/// read here and win over whatever the model computed.
abstract final class ReminderTimeParser {
  static const _number =
      r'(\d+(?:\.\d+)?|a|an|one|two|three|four|five|ten|fifteen|twenty|thirty|half an?)';

  /// "in/after N units", "N units later/from now", Banglish "N unit pore".
  static final _relative = RegExp(
    '(?:\\b(?:in|after|within)\\s+$_number\\s*($_unit))|'
    '(?:\\b$_number\\s*($_unit)\\s*(?:later|from now|pore|por|pare)\\b)',
    caseSensitive: false,
  );
  static const _unit = r'minutes?|mins?|m\b|hours?|hrs?|h\b|ghonta|ghontay|days?|din|minute|minit';

  /// "at 6 pm", "at 6:30pm", "at 18:30", "6 pm".
  static final _clock = RegExp(
    r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b|\bat\s+(\d{1,2}):(\d{2})\b',
    caseSensitive: false,
  );

  static const _words = {
    'a': 1.0,
    'an': 1.0,
    'one': 1.0,
    'two': 2.0,
    'three': 3.0,
    'four': 4.0,
    'five': 5.0,
    'ten': 10.0,
    'fifteen': 15.0,
    'twenty': 20.0,
    'thirty': 30.0,
    'half a': 0.5,
    'half an': 0.5,
  };

  /// A relative delay such as "in 5 minutes", or null.
  static Duration? relativeDelay(String text) {
    final m = _relative.firstMatch(text);
    if (m == null) return null;
    final amountText = (m[1] ?? m[3])!.toLowerCase();
    final unit = (m[2] ?? m[4])!.toLowerCase();
    final amount = _words[amountText] ?? double.tryParse(amountText);
    if (amount == null || amount <= 0) return null;
    final minutes = switch (unit) {
      _ when unit.startsWith('h') || unit.startsWith('ghonta') => amount * 60,
      _ when unit.startsWith('d') => amount * 60 * 24,
      _ => amount,
    };
    return Duration(minutes: minutes.round());
  }

  /// A clock time such as "at 6 pm" on [day] (default today); moved to the
  /// next day when it has already passed. Null when none is mentioned.
  static DateTime? clockTime(String text, {required DateTime now, DateTime? day}) {
    final m = _clock.firstMatch(text);
    if (m == null) return null;
    var hour = int.parse((m[1] ?? m[4])!);
    final minute = int.parse(m[2] ?? m[5] ?? '0');
    final meridiem = m[3]?.toLowerCase();
    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    final base = day ?? now;
    final at = DateTime(base.year, base.month, base.day, hour, minute);
    return at.isAfter(now) || day != null ? at : at.add(const Duration(days: 1));
  }

  /// The reminder time the user asked for in [text], if any.
  static DateTime? parse(String text, {required DateTime now, DateTime? day}) {
    if (relativeDelay(text) case final delay?) return now.add(delay);
    return clockTime(text, now: now, day: day);
  }
}

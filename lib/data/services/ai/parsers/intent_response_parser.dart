import 'dart:convert';

import '../../../../domain/entities/user_intent.dart';

/// Parses the understanding JSON, tolerating code fences and stray prose.
/// Returns null when there is no usable intent.
abstract final class IntentResponseParser {
  static final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _hhmm = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$');
  static const _filters = {'open', 'overdue', 'done', 'today', 'tomorrow'};
  static const _defaultConfidence = 0.7;
  static const _maxText = 200;

  static UserIntent? parse(String raw) {
    final json = _object(raw);
    if (json == null) return null;
    final type = IntentType.fromWire(_text(json['intent']));
    if (type == null) return null;
    final date = _text(json['date']);
    final time = _text(json['time']);
    final filter = _text(json['filter']).toLowerCase();
    final confidence = switch (json['confidence']) {
      final num n => n.toDouble().clamp(0.0, 1.0),
      final String s => (double.tryParse(s) ?? _defaultConfidence).clamp(0.0, 1.0),
      _ => _defaultConfidence,
    };
    return UserIntent(
      type,
      confidence: confidence,
      title: _text(json['title']),
      date: _isoDate.hasMatch(date) ? DateTime.tryParse(date) : null,
      time: _hhmm.hasMatch(time) ? time.padLeft(5, '0') : '',
      taskRef: _text(json['task_ref']),
      query: _text(json['query']),
      note: _text(json['note']),
      filter: _filters.contains(filter) ? filter : '',
      source: IntentSource.model,
    );
  }

  static String _text(Object? value) {
    if (value is! String) return '';
    final t = value.trim();
    return t.length > _maxText ? t.substring(0, _maxText) : t;
  }

  static Map<String, Object?>? _object(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/user_intent.dart';
import '../../../domain/repositories/intent_correction_repository.dart';

/// Keeps the latest corrections in preferences (small, on device only).
final class PrefsIntentCorrectionRepository implements IntentCorrectionRepository {
  PrefsIntentCorrectionRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'intent_corrections';
  static const _maxKept = 30;

  @override
  Future<List<IntentExample>> recent({int limit = 8}) async => _read().take(limit).toList();

  @override
  Future<void> add(IntentExample example) async {
    final kept = [
      example,
      ..._read().where((e) => e.text.toLowerCase() != example.text.toLowerCase()),
    ].take(_maxKept);
    await _prefs.setString(
      _key,
      jsonEncode([
        for (final e in kept) {'text': e.text, 'intent': e.type.wireName},
      ]),
    );
  }

  @override
  Future<void> clear() => _prefs.remove(_key);

  List<IntentExample> _read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List<Object?>)
          if (item case {'text': final String text, 'intent': final String wire})
            if (IntentType.fromWire(wire) case final type?) IntentExample(text, type),
      ];
    } on FormatException {
      return const [];
    }
  }
}

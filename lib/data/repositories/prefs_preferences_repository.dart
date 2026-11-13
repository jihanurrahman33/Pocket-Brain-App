import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/ai_model.dart';
import '../../domain/repositories/preferences_repository.dart';

final class SharedPrefsPreferencesRepository implements PreferencesRepository {
  SharedPrefsPreferencesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _aiSuggestionsKey = 'ai_suggestions';
  static const _backendKey = 'backend';
  static const _aiSetupKey = 'ai_setup_requested';

  @override
  bool get aiSuggestionsEnabled => _prefs.getBool(_aiSuggestionsKey) ?? true;

  @override
  Future<void> setAiSuggestionsEnabled(bool enabled) => _prefs.setBool(_aiSuggestionsKey, enabled);

  @override
  ComputeBackend get computeBackend =>
      ComputeBackend.values.asNameMap()[_prefs.getString(_backendKey)] ?? ComputeBackend.cpu;

  @override
  Future<void> setComputeBackend(ComputeBackend backend) =>
      _prefs.setString(_backendKey, backend.name);

  @override
  bool get aiSetupRequested => _prefs.getBool(_aiSetupKey) ?? false;

  @override
  Future<void> setAiSetupRequested(bool requested) => _prefs.setBool(_aiSetupKey, requested);
}

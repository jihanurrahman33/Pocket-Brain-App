import '../entities/ai_model.dart';

/// User preferences.
abstract interface class PreferencesRepository {
  /// When false, capture skips AI analysis entirely.
  bool get aiSuggestionsEnabled;

  Future<void> setAiSuggestionsEnabled(bool enabled);

  ComputeBackend get computeBackend;

  Future<void> setComputeBackend(ComputeBackend backend);
}

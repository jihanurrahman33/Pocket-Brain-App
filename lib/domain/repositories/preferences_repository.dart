import '../entities/ai_model.dart';

/// User preferences.
abstract interface class PreferencesRepository {
  /// When false, capture skips AI analysis entirely.
  bool get aiSuggestionsEnabled;

  Future<void> setAiSuggestionsEnabled(bool enabled);

  ComputeBackend get computeBackend;

  Future<void> setComputeBackend(ComputeBackend backend);

  /// The user started AI setup and has not cancelled it. Used to resume an
  /// interrupted setup automatically on the next launch.
  bool get aiSetupRequested;

  Future<void> setAiSetupRequested(bool requested);

  AiQuality get aiQuality;

  Future<void> setAiQuality(AiQuality quality);
}

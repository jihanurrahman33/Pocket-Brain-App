import 'dart:async';

import '../../../core/error/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/ai_model.dart';
import '../../repositories/model_repository.dart';
import '../../repositories/preferences_repository.dart';
import '../indexing/indexing_usecases.dart';

/// The AI pack's state plus device settings.
typedef AiOverview = ({AiPackStatus pack, ComputeBackend backend, int storageBytes});

final class GetAiOverview implements UseCase<AiOverview, NoParams> {
  const GetAiOverview(this._models, this._preferences);

  final ModelRepository _models;
  final PreferencesRepository _preferences;

  @override
  Future<AiOverview> call(NoParams _) async => (
    pack: _models.status(),
    backend: _preferences.computeBackend,
    storageBytes: await _models.storageBytes(),
  );
}

/// Downloads the AI pack. Afterwards, memories saved before semantic search
/// existed are indexed in the background.
final class InstallAi implements UseCase<Result<void>, void Function(double progress)> {
  const InstallAi(this._models, this._indexPending);

  final ModelRepository _models;
  final IndexPendingMemories _indexPending;

  @override
  Future<Result<void>> call(void Function(double progress) onProgress) async {
    final result = await _models.install(onProgress: onProgress);
    if (result.isSuccess) unawaited(_indexPending(noParams));
    return result;
  }
}

final class CancelAiInstall implements UseCase<void, NoParams> {
  const CancelAiInstall(this._models);

  final ModelRepository _models;

  @override
  Future<void> call(NoParams _) async => _models.cancelInstall();
}

final class UninstallAi implements UseCase<Result<void>, NoParams> {
  const UninstallAi(this._models);

  final ModelRepository _models;

  @override
  Future<Result<void>> call(NoParams _) => _models.uninstall();
}

/// Saves the preference and reloads the AI on the new backend.
final class ChangeComputeBackend implements UseCase<void, ComputeBackend> {
  const ChangeComputeBackend(this._models, this._preferences);

  final ModelRepository _models;
  final PreferencesRepository _preferences;

  @override
  Future<void> call(ComputeBackend backend) async {
    await _preferences.setComputeBackend(backend);
    await _models.useBackend(backend);
  }
}

final class UnloadModels implements UseCase<void, NoParams> {
  const UnloadModels(this._models);

  final ModelRepository _models;

  @override
  Future<void> call(NoParams _) => _models.unloadAll();
}

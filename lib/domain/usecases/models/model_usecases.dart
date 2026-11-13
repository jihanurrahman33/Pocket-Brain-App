import 'dart:async';

import '../../../core/error/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/ai_model.dart';
import '../../repositories/model_repository.dart';
import '../../repositories/preferences_repository.dart';
import '../indexing/indexing_usecases.dart';

/// A snapshot of every model plus device settings.
typedef ModelOverview = ({List<AiModelStatus> models, ComputeBackend backend, int storageBytes});

final class GetModelOverview implements UseCase<ModelOverview, NoParams> {
  const GetModelOverview(this._models, this._preferences);

  final ModelRepository _models;
  final PreferencesRepository _preferences;

  @override
  Future<ModelOverview> call(NoParams _) async => (
    models: [for (final info in _models.available) _models.status(info.kind)],
    backend: _preferences.computeBackend,
    storageBytes: await _models.storageBytes(),
  );
}

typedef InstallParams = ({AiModelKind kind, void Function(double progress) onProgress});

/// Downloads a model; after the embedder arrives, older memories are
/// indexed in the background so semantic search covers them.
final class InstallModel implements UseCase<Result<void>, InstallParams> {
  const InstallModel(this._models, this._indexPending);

  final ModelRepository _models;
  final IndexPendingMemories _indexPending;

  @override
  Future<Result<void>> call(InstallParams params) async {
    final result = await _models.install(params.kind, onProgress: params.onProgress);
    if (result.isSuccess && params.kind == AiModelKind.embedder) {
      unawaited(_indexPending(noParams));
    }
    return result;
  }
}

final class CancelModelInstall implements UseCase<void, AiModelKind> {
  const CancelModelInstall(this._models);

  final ModelRepository _models;

  @override
  Future<void> call(AiModelKind kind) async => _models.cancelInstall(kind);
}

final class UninstallModel implements UseCase<Result<void>, AiModelKind> {
  const UninstallModel(this._models);

  final ModelRepository _models;

  @override
  Future<Result<void>> call(AiModelKind kind) => _models.uninstall(kind);
}

/// Saves the preference and reloads models on the new backend.
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

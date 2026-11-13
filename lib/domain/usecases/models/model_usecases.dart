import 'dart:async';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/ai_model.dart';
import '../../repositories/model_repository.dart';
import '../../repositories/preferences_repository.dart';
import '../../services/device_memory.dart';
import '../indexing/indexing_usecases.dart';

/// The AI pack's state plus device settings.
///
/// [resumeNeeded] is true when the user started setup and it was interrupted
/// (crash, restart, lost connection) rather than cancelled.
/// [qualities] lists the AI qualities this device can run, in order.
typedef AiOverview = ({
  AiPackStatus pack,
  ComputeBackend backend,
  AiQuality quality,
  List<AiQuality> qualities,
  int storageBytes,
  bool resumeNeeded,
});

final class GetAiOverview implements UseCase<AiOverview, NoParams> {
  const GetAiOverview(this._models, this._preferences, this._qualities);

  final ModelRepository _models;
  final PreferencesRepository _preferences;
  final GetAvailableAiQualities _qualities;

  @override
  Future<AiOverview> call(NoParams _) async {
    final pack = _models.status();
    return (
      pack: pack,
      backend: _preferences.computeBackend,
      quality: _preferences.aiQuality,
      qualities: await _qualities(noParams),
      storageBytes: await _models.storageBytes(),
      resumeNeeded: _preferences.aiSetupRequested && !pack.isInstalled,
    );
  }
}

/// The AI qualities this device has enough memory for. Phones with 4–6 GB
/// get only [AiQuality.standard]; the larger model would not fit beside the
/// OS and other apps.
final class GetAvailableAiQualities implements UseCase<List<AiQuality>, NoParams> {
  const GetAvailableAiQualities(this._memory);

  final DeviceMemory _memory;

  /// "8 GB" devices report a little less (the kernel and GPU reserve some).
  static const highQualityMinBytes = 7 * 1024 * 1024 * 1024;

  @override
  Future<List<AiQuality>> call(NoParams _) async {
    final total = await _memory.totalBytes();
    return [AiQuality.standard, if (total != null && total >= highQualityMinBytes) AiQuality.high];
  }
}

/// Switches the AI quality. The new model is downloaded by [InstallAi]
/// (resumable, like the first setup); the current one keeps answering until
/// it is ready and is then removed.
final class ChangeAiQuality implements UseCase<Result<void>, AiQuality> {
  const ChangeAiQuality(this._models, this._preferences, this._qualities);

  final ModelRepository _models;
  final PreferencesRepository _preferences;
  final GetAvailableAiQualities _qualities;

  @override
  Future<Result<void>> call(AiQuality quality) async {
    if (!(await _qualities(noParams)).contains(quality)) {
      return const Err(ModelFailure('This device does not have enough memory for that.'));
    }
    await _preferences.setAiQuality(quality);
    await _models.useQuality(quality);
    return const Success(null);
  }
}

/// Downloads the AI pack. Afterwards, memories saved before semantic search
/// existed are indexed in the background.
///
/// Setup is remembered as requested until it completes, so an interrupted
/// download resumes on the next launch (see [GetAiOverview]).
final class InstallAi implements UseCase<Result<void>, void Function(double progress)> {
  const InstallAi(this._models, this._preferences, this._indexPending);

  final ModelRepository _models;
  final PreferencesRepository _preferences;
  final IndexPendingMemories _indexPending;

  @override
  Future<Result<void>> call(void Function(double progress) onProgress) async {
    await _preferences.setAiSetupRequested(true);
    final result = await _models.install(onProgress: onProgress);
    if (result.isSuccess) {
      await _preferences.setAiSetupRequested(false);
      unawaited(_indexPending(noParams));
    }
    return result;
  }
}

/// Stops the download. Downloaded bytes are kept, so tapping "Resume" later
/// continues from the same point, but it will not resume on its own.
final class CancelAiInstall implements UseCase<void, NoParams> {
  const CancelAiInstall(this._models, this._preferences);

  final ModelRepository _models;
  final PreferencesRepository _preferences;

  @override
  Future<void> call(NoParams _) async {
    await _preferences.setAiSetupRequested(false);
    _models.cancelInstall();
  }
}

final class UninstallAi implements UseCase<Result<void>, NoParams> {
  const UninstallAi(this._models, this._preferences);

  final ModelRepository _models;
  final PreferencesRepository _preferences;

  @override
  Future<Result<void>> call(NoParams _) async {
    await _preferences.setAiSetupRequested(false);
    return _models.uninstall();
  }
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

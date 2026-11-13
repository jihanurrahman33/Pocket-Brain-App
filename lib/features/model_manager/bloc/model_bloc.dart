import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/ai_model.dart';
import '../../../domain/usecases/models/model_usecases.dart';

part 'model_event.dart';
part 'model_state.dart';

/// App-wide status of the on-device models.
class ModelBloc extends Bloc<ModelEvent, ModelState> {
  ModelBloc({
    required GetModelOverview getOverview,
    required InstallModel installModel,
    required CancelModelInstall cancelInstall,
    required UninstallModel uninstallModel,
    required ChangeComputeBackend changeBackend,
    required UnloadModels unloadModels,
  }) : _getOverview = getOverview,
       _installModel = installModel,
       _cancelInstall = cancelInstall,
       _uninstallModel = uninstallModel,
       _changeBackend = changeBackend,
       _unloadModels = unloadModels,
       super(const ModelState()) {
    on<ModelRefreshRequested>(_onRefresh, transformer: restartable());
    on<ModelInstallRequested>(_onInstall);
    on<ModelInstallCancelled>(_onCancel);
    on<ModelUninstallRequested>(_onUninstall);
    on<ModelBackendChanged>(_onBackendChanged);
    on<ModelUnloadRequested>(_onUnload);
  }

  final GetModelOverview _getOverview;
  final InstallModel _installModel;
  final CancelModelInstall _cancelInstall;
  final UninstallModel _uninstallModel;
  final ChangeComputeBackend _changeBackend;
  final UnloadModels _unloadModels;

  Future<void> _onRefresh(ModelRefreshRequested event, Emitter<ModelState> emit) async {
    final overview = await _getOverview.run();
    emit(
      state.copyWith(
        models: {
          for (final status in overview.models)
            status.info.kind: state.slots[status.info.kind]?.isDownloading ?? false
                ? state.slots[status.info.kind]!
                : ModelSlot(status: status),
        },
        backend: overview.backend,
        storageBytes: overview.storageBytes,
      ),
    );
  }

  Future<void> _onInstall(ModelInstallRequested event, Emitter<ModelState> emit) async {
    final slot = state.slots[event.kind];
    if (slot == null || slot.isDownloading) return;
    emit(state.withSlot(event.kind, slot.downloading(0)));

    final progress = StreamController<double>();
    final install = _installModel((kind: event.kind, onProgress: progress.add))
        .whenComplete(progress.close);
    await emit.forEach<double>(
      progress.stream,
      onData: (p) => state.withSlot(event.kind, state.slots[event.kind]!.downloading(p)),
    );
    final result = await install;
    final failure = result.failureOrNull;
    final overview = await _getOverview.run();
    final status = overview.models.firstWhere((s) => s.info.kind == event.kind);
    emit(
      state
          .withSlot(
            event.kind,
            ModelSlot(status: status, failure: failure is CancelledFailure ? null : failure),
          )
          .copyWith(storageBytes: overview.storageBytes),
    );
  }

  Future<void> _onCancel(ModelInstallCancelled event, Emitter<ModelState> emit) =>
      _cancelInstall(event.kind);

  Future<void> _onUninstall(ModelUninstallRequested event, Emitter<ModelState> emit) async {
    final result = await _uninstallModel(event.kind);
    if (result.failureOrNull case final failure?) {
      emit(state.withSlot(event.kind, state.slots[event.kind]!.withFailure(failure)));
      return;
    }
    add(const ModelRefreshRequested());
  }

  Future<void> _onBackendChanged(ModelBackendChanged event, Emitter<ModelState> emit) async {
    await _changeBackend(event.backend);
    add(const ModelRefreshRequested());
  }

  Future<void> _onUnload(ModelUnloadRequested event, Emitter<ModelState> emit) async {
    await _unloadModels.run();
    add(const ModelRefreshRequested());
  }
}

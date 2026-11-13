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

/// App-wide state of the on-device "Pocket Brain AI" pack.
class ModelBloc extends Bloc<ModelEvent, ModelState> {
  ModelBloc({
    required GetAiOverview getOverview,
    required InstallAi installAi,
    required CancelAiInstall cancelInstall,
    required UninstallAi uninstallAi,
    required ChangeComputeBackend changeBackend,
    required UnloadModels unloadModels,
  }) : _getOverview = getOverview,
       _installAi = installAi,
       _cancelInstall = cancelInstall,
       _uninstallAi = uninstallAi,
       _changeBackend = changeBackend,
       _unloadModels = unloadModels,
       super(const ModelState()) {
    on<ModelRefreshRequested>((_, emit) => _refresh(emit), transformer: restartable());
    on<ModelInstallRequested>(_onInstall, transformer: droppable());
    on<ModelInstallCancelled>((_, _) => _cancelInstall.run());
    on<ModelUninstallRequested>(_onUninstall);
    on<ModelBackendChanged>(_onBackendChanged);
    on<ModelUnloadRequested>(_onUnload);
  }

  final GetAiOverview _getOverview;
  final InstallAi _installAi;
  final CancelAiInstall _cancelInstall;
  final UninstallAi _uninstallAi;
  final ChangeComputeBackend _changeBackend;
  final UnloadModels _unloadModels;

  Future<void> _refresh(Emitter<ModelState> emit, {Failure? failure}) async {
    final overview = await _getOverview.run();
    emit(
      ModelState(
        pack: overview.pack,
        backend: overview.backend,
        storageBytes: overview.storageBytes,
        failure: failure,
      ),
    );
  }

  Future<void> _onInstall(ModelInstallRequested event, Emitter<ModelState> emit) async {
    if (state.isDownloading || (state.pack?.isInstalled ?? false)) return;
    emit(state.downloading(0));
    final progress = StreamController<double>();
    final install = _installAi(progress.add).whenComplete(progress.close);
    await emit.forEach<double>(progress.stream, onData: state.downloading);
    final failure = (await install).failureOrNull;
    // A cancelled download is not an error worth showing.
    await _refresh(emit, failure: failure is CancelledFailure ? null : failure);
  }

  Future<void> _onUninstall(ModelUninstallRequested event, Emitter<ModelState> emit) async {
    final result = await _uninstallAi.run();
    await _refresh(emit, failure: result.failureOrNull);
  }

  Future<void> _onBackendChanged(ModelBackendChanged event, Emitter<ModelState> emit) async {
    await _changeBackend(event.backend);
    await _refresh(emit);
  }

  Future<void> _onUnload(ModelUnloadRequested event, Emitter<ModelState> emit) async {
    await _unloadModels.run();
    await _refresh(emit);
  }
}

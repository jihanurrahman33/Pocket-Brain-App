part of 'model_bloc.dart';

sealed class ModelEvent extends Equatable {
  const ModelEvent();

  @override
  List<Object?> get props => [];
}

/// App launch: load state and auto-resume an interrupted setup.
final class ModelStarted extends ModelEvent {
  const ModelStarted();
}

/// Re-reads install state.
final class ModelRefreshRequested extends ModelEvent {
  const ModelRefreshRequested();
}

/// Downloads everything Pocket Brain AI still needs, as one download.
final class ModelInstallRequested extends ModelEvent {
  const ModelInstallRequested();
}

final class ModelInstallCancelled extends ModelEvent {
  const ModelInstallCancelled();
}

final class ModelUninstallRequested extends ModelEvent {
  const ModelUninstallRequested();
}

final class ModelBackendChanged extends ModelEvent {
  const ModelBackendChanged(this.backend);

  final ComputeBackend backend;

  @override
  List<Object?> get props => [backend];
}

/// Frees RAM used by the AI.
final class ModelUnloadRequested extends ModelEvent {
  const ModelUnloadRequested();
}

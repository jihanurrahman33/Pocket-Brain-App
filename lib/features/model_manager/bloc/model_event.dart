part of 'model_bloc.dart';

sealed class ModelEvent extends Equatable {
  const ModelEvent();

  @override
  List<Object?> get props => [];
}

/// Re-reads install state.
final class ModelRefreshRequested extends ModelEvent {
  const ModelRefreshRequested();
}

final class ModelInstallRequested extends ModelEvent {
  const ModelInstallRequested(this.kind);

  final AiModelKind kind;

  @override
  List<Object?> get props => [kind];
}

final class ModelInstallCancelled extends ModelEvent {
  const ModelInstallCancelled(this.kind);

  final AiModelKind kind;

  @override
  List<Object?> get props => [kind];
}

final class ModelUninstallRequested extends ModelEvent {
  const ModelUninstallRequested(this.kind);

  final AiModelKind kind;

  @override
  List<Object?> get props => [kind];
}

final class ModelBackendChanged extends ModelEvent {
  const ModelBackendChanged(this.backend);

  final ComputeBackend backend;

  @override
  List<Object?> get props => [backend];
}

/// Frees RAM used by loaded models.
final class ModelUnloadRequested extends ModelEvent {
  const ModelUnloadRequested();
}

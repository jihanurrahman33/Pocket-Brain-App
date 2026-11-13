part of 'model_bloc.dart';

/// One model as shown in the UI: its status plus any download in progress.
class ModelSlot extends Equatable {
  const ModelSlot({required this.status, this.progress, this.failure});

  final AiModelStatus status;

  /// Download progress in [0, 1]; null when not downloading.
  final double? progress;
  final Failure? failure;

  AiModelInfo get info => status.info;

  bool get isInstalled => status.installed;

  bool get isDownloading => progress != null;

  ModelSlot downloading(double progress) => ModelSlot(status: status, progress: progress);

  ModelSlot withFailure(Failure failure) => ModelSlot(status: status, failure: failure);

  @override
  List<Object?> get props => [status, progress, failure];
}

class ModelState extends Equatable {
  const ModelState({
    this.slots = const {},
    this.backend = ComputeBackend.cpu,
    this.storageBytes = 0,
  });

  final Map<AiModelKind, ModelSlot> slots;
  final ComputeBackend backend;
  final int storageBytes;

  ModelSlot? get languageModel => slots[AiModelKind.languageModel];

  bool get isLanguageModelReady => languageModel?.isInstalled ?? false;

  ModelState withSlot(AiModelKind kind, ModelSlot slot) => copyWith(models: {...slots, kind: slot});

  ModelState copyWith({
    Map<AiModelKind, ModelSlot>? models,
    ComputeBackend? backend,
    int? storageBytes,
  }) => ModelState(
    slots: models ?? slots,
    backend: backend ?? this.backend,
    storageBytes: storageBytes ?? this.storageBytes,
  );

  @override
  List<Object?> get props => [slots, backend, storageBytes];
}

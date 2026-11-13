import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/clock.dart';
import '../../../domain/entities/capture.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/memory_analysis.dart';
import '../../../domain/entities/memory_collection.dart';
import '../../../domain/usecases/capture/capture_usecases.dart';
import '../../../domain/usecases/capture/voice_usecases.dart';
import '../../../domain/usecases/collections/collection_usecases.dart';

part 'capture_event.dart';
part 'capture_state.dart';

/// Capture → review AI suggestions → confirm. Nothing is saved until the
/// user confirms, and their original text is never altered.
class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  CaptureBloc({
    required AnalyzeCapture analyzeCapture,
    required SaveCapture saveCapture,
    required GetCollections getCollections,
    required StartVoiceRecording startRecording,
    required StopVoiceRecording stopRecording,
    required CancelVoiceRecording cancelRecording,
    required Clock clock,
  }) : _analyzeCapture = analyzeCapture,
       _saveCapture = saveCapture,
       _getCollections = getCollections,
       _startRecording = startRecording,
       _stopRecording = stopRecording,
       _cancelRecording = cancelRecording,
       _clock = clock,
       super(const CaptureEditing()) {
    on<CaptureStarted>(_onStarted);
    on<CaptureSubmitted>(_onSubmitted, transformer: droppable());
    on<CaptureReviewEdited>(_onReviewEdited);
    on<CaptureTaskToggled>(_onTaskToggled);
    on<CaptureConfirmed>(_onConfirmed, transformer: droppable());
    on<CaptureDiscarded>(_onDiscarded);
    on<CaptureRecordingStarted>(_onRecordingStarted, transformer: droppable());
    on<CaptureRecordingStopped>(_onRecordingStopped, transformer: droppable());
    on<CaptureRecordingCancelled>(_onRecordingCancelled);
  }

  final AnalyzeCapture _analyzeCapture;
  final SaveCapture _saveCapture;
  final GetCollections _getCollections;
  final StartVoiceRecording _startRecording;
  final StopVoiceRecording _stopRecording;
  final CancelVoiceRecording _cancelRecording;
  final Clock _clock;

  Future<void> _onStarted(CaptureStarted event, Emitter<CaptureState> emit) async {
    emit(const CaptureEditing());
  }

  Future<void> _onSubmitted(CaptureSubmitted event, Emitter<CaptureState> emit) async {
    emit(CaptureAnalyzing(event.input));
    final draft = await _analyzeCapture(event.input);
    final collections = (await _getCollections.run()).valueOrNull ?? const [];
    draft.fold(
      onSuccess: (d) => emit(CaptureReviewing(CaptureReview.fromDraft(d, collections))),
      // Keep the user's text: losing a note because analysis failed is worse
      // than the failure itself.
      onFailure: (f) => emit(CaptureEditing(failure: f, input: event.input)),
    );
  }

  void _onReviewEdited(CaptureReviewEdited event, Emitter<CaptureState> emit) {
    if (state case CaptureReviewing(:final review)) {
      emit(CaptureReviewing(event.apply(review)));
    }
  }

  void _onTaskToggled(CaptureTaskToggled event, Emitter<CaptureState> emit) {
    if (state case CaptureReviewing(:final review)) {
      emit(CaptureReviewing(review.toggleTask(event.index)));
    }
  }

  Future<void> _onConfirmed(CaptureConfirmed event, Emitter<CaptureState> emit) async {
    final current = state;
    if (current is! CaptureReviewing) return;
    emit(CaptureReviewing(current.review, isSaving: true));
    final result = await _saveCapture(current.review.toRequest());
    result.fold(
      onSuccess: (memory) => emit(CaptureSaved(memory.id)),
      onFailure: (f) => emit(CaptureReviewing(current.review, failure: f)),
    );
  }

  void _onDiscarded(CaptureDiscarded event, Emitter<CaptureState> emit) =>
      emit(const CaptureEditing());

  Future<void> _onRecordingStarted(
    CaptureRecordingStarted event,
    Emitter<CaptureState> emit,
  ) async {
    if (state is CaptureRecording) return;
    final result = await _startRecording.run();
    result.fold(
      onSuccess: (_) => emit(CaptureRecording(startedAt: _clock.now(), note: event.note)),
      onFailure: (f) => emit(CaptureEditing(failure: f)),
    );
  }

  /// Stops recording and analyses it right away, like a submitted capture.
  Future<void> _onRecordingStopped(
    CaptureRecordingStopped event,
    Emitter<CaptureState> emit,
  ) async {
    final recording = state;
    if (recording is! CaptureRecording) return;
    final result = await _stopRecording.run();
    switch (result) {
      case Success(value: final path):
        await _onSubmitted(
          CaptureSubmitted(
            CaptureInput(
              text: recording.note,
              source: MemorySource.voice,
              media: CapturedMedia(path: path, kind: AttachmentKind.audio),
            ),
          ),
          emit,
        );
      case Err(:final failure):
        emit(CaptureEditing(failure: failure));
    }
  }

  Future<void> _onRecordingCancelled(
    CaptureRecordingCancelled event,
    Emitter<CaptureState> emit,
  ) async {
    await _cancelRecording.run();
    emit(const CaptureEditing());
  }
}

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/capture.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/memory_analysis.dart';
import '../../../domain/entities/memory_collection.dart';
import '../../../domain/usecases/capture/capture_usecases.dart';
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
  }) : _analyzeCapture = analyzeCapture,
       _saveCapture = saveCapture,
       _getCollections = getCollections,
       super(const CaptureEditing()) {
    on<CaptureStarted>(_onStarted);
    on<CaptureSubmitted>(_onSubmitted, transformer: droppable());
    on<CaptureReviewEdited>(_onReviewEdited);
    on<CaptureTaskToggled>(_onTaskToggled);
    on<CaptureConfirmed>(_onConfirmed, transformer: droppable());
    on<CaptureDiscarded>(_onDiscarded);
  }

  final AnalyzeCapture _analyzeCapture;
  final SaveCapture _saveCapture;
  final GetCollections _getCollections;

  Future<void> _onStarted(CaptureStarted event, Emitter<CaptureState> emit) async {
    emit(const CaptureEditing());
  }

  Future<void> _onSubmitted(CaptureSubmitted event, Emitter<CaptureState> emit) async {
    emit(const CaptureAnalyzing());
    final draft = await _analyzeCapture(event.input);
    final collections = (await _getCollections.run()).valueOrNull ?? const [];
    draft.fold(
      onSuccess: (d) => emit(CaptureReviewing(CaptureReview.fromDraft(d, collections))),
      onFailure: (f) => emit(CaptureEditing(failure: f)),
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
}

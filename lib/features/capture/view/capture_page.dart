import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feedback_widgets.dart';
import '../../../domain/entities/capture.dart';
import '../../../domain/entities/memory.dart';
import '../../shared/widgets/memory_views.dart';
import '../bloc/capture_bloc.dart';
import '../widgets/capture_input_form.dart';
import '../widgets/capture_review_view.dart';
import '../widgets/recording_view.dart';

class CapturePage extends StatelessWidget {
  const CapturePage({super.key});

  void _onStateChanged(BuildContext context, CaptureState state) {
    switch (state) {
      case CaptureSaved(:final memoryId):
        context.showMessage(
          'Saved to your brain',
          action: SnackBarAction(label: 'Open', onPressed: () => openMemory(context, memoryId)),
        );
        context.read<CaptureBloc>().add(const CaptureStarted());
      case CaptureEditing(failure: final failure?) || CaptureReviewing(failure: final failure?):
        context.showFailure(failure);
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CaptureBloc, CaptureState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final reviewing = state is CaptureReviewing;
        return Scaffold(
          appBar: AppBar(
            title: Text(reviewing ? 'Review memory' : 'Capture'),
            leading: reviewing
                ? IconButton(
                    tooltip: 'Discard',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => context.read<CaptureBloc>().add(const CaptureDiscarded()),
                  )
                : null,
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: switch (state) {
              CaptureEditing(:final input) => CaptureInputForm(initialInput: input),
              CaptureSaved() => const CaptureInputForm(),
              CaptureRecording() => RecordingView(state: state),
              CaptureAnalyzing(:final input) => _AnalyzingView(input: input),
              CaptureReviewing() => CaptureReviewView(
                key: ValueKey(state.review.draft),
                state: state,
              ),
            },
          ),
        );
      },
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView({required this.input});

  final CaptureInput input;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (input.media?.kind) {
      AttachmentKind.image => (Icons.image_search_rounded, 'Reading your image…'),
      AttachmentKind.audio => (Icons.graphic_eq_rounded, 'Transcribing your voice note…'),
      null => (Icons.auto_awesome_rounded, 'Understanding your memory…'),
    };
    return EmptyState(
      icon: icon,
      title: title,
      message: input.media == null
          ? 'Running privately on this device.'
          : 'Running privately on this device. Images and audio take a little longer.',
      action: const CircularProgressIndicator(),
    );
  }
}

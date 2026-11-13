import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feedback_widgets.dart';
import '../../shared/widgets/memory_views.dart';
import '../bloc/capture_bloc.dart';
import '../widgets/capture_input_form.dart';
import '../widgets/capture_review_view.dart';

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
              CaptureAnalyzing() => const _AnalyzingView(),
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
  const _AnalyzingView();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.auto_awesome_rounded,
    title: 'Understanding your memory…',
    message: 'Running privately on this device.',
    action: CircularProgressIndicator(),
  );
}

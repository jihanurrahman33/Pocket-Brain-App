import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_header.dart';
import '../bloc/capture_bloc.dart';

/// Shown while a voice note is being recorded.
class RecordingView extends StatefulWidget {
  const RecordingView({super.key, required this.state});

  final CaptureRecording state;

  /// Long notes take long to transcribe on a phone; stop automatically.
  static const maxDuration = Duration(minutes: 5);

  @override
  State<RecordingView> createState() => _RecordingViewState();
}

class _RecordingViewState extends State<RecordingView> {
  late final Timer _ticker;
  Duration _elapsed = Duration.zero;

  static const _iconSize = 64.0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = DateTime.now().difference(widget.state.startedAt));
      if (_elapsed >= RecordingView.maxDuration) _stop();
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _stop() => context.read<CaptureBloc>().add(const CaptureRecordingStopped());

  static String _format(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_rounded, size: _iconSize, color: theme.colorScheme.error),
            const Gap.md(),
            Text('Recording…', style: theme.textTheme.titleLarge),
            const Gap.xs(),
            Text(_format(_elapsed), style: theme.textTheme.displaySmall),
            const Gap.sm(),
            Text(
              'Speak naturally. Your voice is transcribed on this device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap.xl(),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      context.read<CaptureBloc>().add(const CaptureRecordingCancelled()),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop and continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

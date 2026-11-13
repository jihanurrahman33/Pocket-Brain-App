import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/capture.dart';
import '../../../domain/entities/memory.dart';
import '../../shared/widgets/memory_source_icon.dart';
import '../bloc/capture_bloc.dart';

/// Source types the user can pick. Voice, image and PDF are planned.
const _availableSources = [MemorySource.note, MemorySource.link, MemorySource.clipboard];
const _plannedSources = [MemorySource.voice, MemorySource.image, MemorySource.pdf];

class CaptureInputForm extends StatefulWidget {
  const CaptureInputForm({super.key, this.initialInput});

  /// Restores text after a failed submit.
  final CaptureInput? initialInput;

  @override
  State<CaptureInputForm> createState() => _CaptureInputFormState();
}

class _CaptureInputFormState extends State<CaptureInputForm> {
  late final _text = TextEditingController(text: widget.initialInput?.text);
  late final _url = TextEditingController(text: widget.initialInput?.url);
  late MemorySource _source = widget.initialInput?.source ?? MemorySource.note;

  static const _minLines = 8;
  static const _maxLines = 18;

  @override
  void dispose() {
    _text.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _selectSource(MemorySource source) async {
    if (source == MemorySource.clipboard) return _pasteFromClipboard();
    setState(() => _source = source);
  }

  Future<void> _pasteFromClipboard() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) return context.showMessage('The clipboard is empty');
    final looksLikeUrl = (Uri.tryParse(text)?.hasScheme ?? false) && !text.contains(' ');
    setState(() {
      _source = looksLikeUrl ? MemorySource.link : MemorySource.clipboard;
      (looksLikeUrl ? _url : _text).text = text;
    });
  }

  void _submit() {
    final input = CaptureInput(
      text: _text.text,
      source: _source,
      url: _source == MemorySource.link ? _url.text : null,
    );
    if (input.isEmpty) return;
    context.read<CaptureBloc>().add(CaptureSubmitted(input));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLink = _source == MemorySource.link;
    return ResponsiveListView(
      children: [
        Text('What do you want to remember?', style: theme.textTheme.titleLarge),
        const Gap.md(),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final source in _availableSources)
              ChoiceChip(
                avatar: Icon(source.icon, size: AppSpacing.lg + AppSpacing.xxs),
                label: Text(_labelFor(source)),
                selected: _source == source,
                onSelected: (_) => _selectSource(source),
              ),
            for (final source in _plannedSources)
              Tooltip(
                message: 'Coming in the next release',
                child: ChoiceChip(
                  avatar: Icon(source.icon, size: AppSpacing.lg + AppSpacing.xxs),
                  label: Text('${source.label} · soon'),
                  selected: false,
                  onSelected: null,
                ),
              ),
          ],
        ),
        const Gap.lg(),
        if (isLink) ...[
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://…',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const Gap.md(),
        ],
        CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit},
          child: TextField(
            controller: _text,
            autofocus: true,
            minLines: _minLines,
            maxLines: _maxLines,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: isLink
                  ? 'Why are you saving this? (optional)'
                  : 'Type or paste anything… ideas, plans, things you read.',
            ),
          ),
        ),
        const Gap.lg(),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Text(
              'Ctrl + Enter to continue · you review everything before saving',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }

  static String _labelFor(MemorySource source) => switch (source) {
    MemorySource.note => 'Write a note',
    MemorySource.link => 'Paste a link',
    MemorySource.clipboard => 'From clipboard',
    _ => source.label,
  };
}

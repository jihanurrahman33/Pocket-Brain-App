import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/memory_analysis.dart';
import '../../shared/widgets/memory_views.dart';
import '../bloc/capture_bloc.dart';

/// "AI understood your memory": editable suggestions, confirmed tasks,
/// related memories and the original text.
class CaptureReviewView extends StatelessWidget {
  const CaptureReviewView({super.key, required this.state});

  final CaptureReviewing state;

  @override
  Widget build(BuildContext context) {
    final review = state.review;
    return AdaptiveTwoPane(
      secondaryWidth: AppSpacing.sidePaneWidth + AppSpacing.xxl * 2,
      primary: [_SuggestionsCard(review: review)],
      footer: [
        const Gap.lg(),
        _SaveBar(isSaving: state.isSaving),
      ],
      secondary: [
        if (review.tasks.isNotEmpty) _SuggestedTasks(tasks: review.tasks),
        if (review.draft.similar.isNotEmpty) ...[
          SectionHeader(
            review.draft.likelyDuplicate != null
                ? 'This looks like something you already saved'
                : 'You already saved ${Formatters.plural(review.draft.similar.length, 'related memory', 'related memories')}',
          ),
          MemoryTileList(memories: [for (final s in review.draft.similar) s.memory]),
        ],
        const SectionHeader('Your original'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SelectableText(review.draft.content, maxLines: 14),
          ),
        ),
      ],
    );
  }
}

class _SuggestionsCard extends StatefulWidget {
  const _SuggestionsCard({required this.review});

  final CaptureReview review;

  @override
  State<_SuggestionsCard> createState() => _SuggestionsCardState();
}

class _SuggestionsCardState extends State<_SuggestionsCard> {
  late final _title = TextEditingController(text: widget.review.title);
  late final _summary = TextEditingController(text: widget.review.summary);
  final _newTag = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _newTag.dispose();
    super.dispose();
  }

  void _edit(CaptureReviewEdited event) => context.read<CaptureBloc>().add(event);

  void _addTag(String value) {
    final tag = value.trim().toLowerCase();
    if (tag.isEmpty || widget.review.tags.contains(tag)) return;
    _edit(CaptureReviewEdited(tags: [...widget.review.tags, tag]));
    _newTag.clear();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final theme = Theme.of(context);
    final origin = review.analysis.origin;
    return Card(
      color: theme.colorScheme.aiContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  origin == AnalysisOrigin.model
                      ? 'AI understood your memory'
                      : 'Quick suggestions',
                  style: theme.textTheme.titleMedium,
                ),
                AiBadge(
                  label: switch (origin) {
                    AnalysisOrigin.model => 'Gemma · editable',
                    AnalysisOrigin.rules => 'Offline rules · editable',
                    AnalysisOrigin.none => 'AI off · editable',
                  },
                ),
              ],
            ),
            if (origin == AnalysisOrigin.rules)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Download Gemma 4 in Settings for smarter titles, summaries and tags.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const Gap.lg(),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (v) => _edit(CaptureReviewEdited(title: v)),
            ),
            const Gap.md(),
            TextField(
              controller: _summary,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Summary'),
              onChanged: (v) => _edit(CaptureReviewEdited(summary: v)),
            ),
            const Gap.md(),
            _CategoryAndCollection(review: review, onEdit: _edit),
            const Gap.md(),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in review.tags)
                  InputChip(
                    label: Text('#$tag'),
                    onDeleted: () =>
                        _edit(CaptureReviewEdited(tags: [...review.tags]..remove(tag))),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: TextField(
                    controller: _newTag,
                    decoration: const InputDecoration(hintText: 'Add tag', isDense: true),
                    onSubmitted: _addTag,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Category and collection pickers: side by side when there is room,
/// stacked on narrow screens.
class _CategoryAndCollection extends StatelessWidget {
  const _CategoryAndCollection({required this.review, required this.onEdit});

  final CaptureReview review;
  final ValueChanged<CaptureReviewEdited> onEdit;

  static const _sideBySideMinWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final category = DropdownButtonFormField<String>(
      initialValue: review.category,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Category'),
      items: [for (final c in review.categoryOptions) DropdownMenuItem(value: c, child: Text(c))],
      onChanged: (v) => onEdit(CaptureReviewEdited(category: v)),
    );
    final collection = DropdownButtonFormField<String?>(
      initialValue: review.collectionId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Collection'),
      items: [
        const DropdownMenuItem(value: null, child: Text('None')),
        for (final c in review.collections)
          DropdownMenuItem(
            value: c.id,
            child: Text(c.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) => onEdit(CaptureReviewEdited(collection: (id: id))),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= _sideBySideMinWidth
          ? Row(
              children: [
                Expanded(child: category),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: collection),
              ],
            )
          : Column(children: [category, const Gap.md(), collection]),
    );
  }
}

class _SuggestedTasks extends StatelessWidget {
  const _SuggestedTasks({required this.tasks});

  final List<SuggestedTask> tasks;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader('Suggested tasks'),
      Card(
        child: Column(
          children: [
            for (final (i, task) in tasks.indexed)
              CheckboxListTile(
                value: task.selected,
                onChanged: (_) => context.read<CaptureBloc>().add(CaptureTaskToggled(i)),
                title: Text(task.title),
                subtitle: task.dueAt == null
                    ? null
                    : Text('Deadline: ${Formatters.friendlyDate(task.dueAt!)}'),
                secondary: const Icon(Icons.task_alt_rounded),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              child: Text(
                'Checked tasks are added to Tasks & Reminders when you save.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.isSaving});

  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CaptureBloc>();
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        TextButton(
          onPressed: () => bloc.add(const CaptureDiscarded()),
          child: const Text('Discard'),
        ),
        FilledButton.icon(
          onPressed: isSaving ? null : () => bloc.add(const CaptureConfirmed()),
          icon: isSaving ? const InlineSpinner() : const Icon(Icons.check_rounded),
          label: const Text('Save to brain'),
        ),
      ],
    );
  }
}

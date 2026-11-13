import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xl, 0, AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

/// Vertical spacing between list items.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  const Gap.xs({super.key}) : size = AppSpacing.xs;

  const Gap.sm({super.key}) : size = AppSpacing.sm;

  const Gap.md({super.key}) : size = AppSpacing.md;

  const Gap.lg({super.key}) : size = AppSpacing.lg;

  const Gap.xl({super.key}) : size = AppSpacing.xl;

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size);
}
